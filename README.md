[![Gem Version](https://badge.fury.io/rb/active_delivery.svg)](https://badge.fury.io/rb/active_delivery)
[![Build Status](https://travis-ci.org/palkan/active_delivery.svg?branch=master)](https://travis-ci.org/palkan/active_delivery)

# Active Delivery

Framework providing an entrypoint (single _interface_) for all types of notifications: mailers, push notifications, whatever you want.

<a href="https://evilmartians.com/?utm_source=action_policy">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

Requirements:
- Ruby ~> 2.3

**NOTE**: although most of the examples in this readme are Rails-specific, this gem could be used without Rails/ActiveSupport.

## The problem

We need a way to handle different notifications _channel_ (mail, push) in one place.

From the business-logic point of view we want to _notify_ a user, hence we need a _separate abstraction layer_ as an entrypoint to different types of notifications.

## The solution

Here comes the _Active Delivery_.

In the simplest case when we have only mailers Active Delivery is just a wrapper for Mailer with (possibly) some additional logic provided (e.g. preventing emails to unsubscribed users).

Motivations behind Active Delivery:
- organize notifications related logic:

```ruby
# Before
def after_some_action
  MyMailer.with(user: user).some_action.deliver_later if user.receive_emails?
  NotifyService.send_notification(user, "action") if whatever_else?
end

# After
def after_some_action
  MyDelivery.with(user: user).notify(:some_action)
end
```

- better testability (see [Testing](#testing)).


## Usage

_Delivery_ class is used to trigger notifications. It describes how to notify a user (e.g. via email or via push notification or both):

```ruby
class PostsDelivery < ActiveDelivery::Base
  # in most cases you don't have to specify anything in this class,
  # 'cause default transport-level classes (such as mailers)
end
```

It acts like a proxy in front of the different delivery channels (i.e. mailers, notifiers). That means that calling a method on delivery class invokes the same method on the corresponding class, e.g.:

```ruby
PostsDelivery.notify(:published, user, post)

# under the hood it calls
PostsMailer.published(user, post).deliver_later

# and if you have a notifier (or anything else)
PostsNotifier.published(user, post).notify_later
```

P.S. Naming ("delivery") is inspired by Basecamp: https://www.youtube.com/watch?v=m1jOWu7woKM.

Delivery also supports _parameterized_ calling:

```ruby
   PostsDelivery.with(user: user).notify(:published, post)
```

The parameters could be accessed through `params` instance method (e.g. to implement guard-like logic).

**NOTE**: When params are presents the parametrized mailer is used, i.e.:

```ruby
PostsMailer.with(user: user).published(post)
```

See [Rails docs](https://api.rubyonrails.org/classes/ActionMailer/Parameterized.html) for more information on parameterized mailers.

## Callbacks support

**NOTE:** callbacks are only available if ActiveSupport is present in the app's env.

```ruby
# Run method before delivering notification
# NOTE: when `false` is returned the executation is halted
before_notify :do_something

# You can specify a notification method (to run callback only for that method)
before_notify :do_mail_something, on: :mailer

# after_ and around_ callbacks are also supported
after_notify :cleanup

around_notify :set_context
```

## Testing

**NOTE:** RSpec only for the time being.

Active Delivery provides an elegant way to test deliveries in your code (i.e. when you want to test whether a notification has been sent) through a `have_delivered_to` matcher:

```ruby
it "delivers notification" do
  expect { subject }.to have_delivered_to(Community::EventsDelivery, :modified, event)
    .with(profile: profile)
```

You can also use such RSpec features as [compound expectations](https://relishapp.com/rspec/rspec-expectations/docs/compound-expectations) and [composed matchers](https://relishapp.com/rspec/rspec-expectations/v/3-8/docs/composing-matchers):

```ruby
it "delivers to rsvped members via .notify" do
  expect { subject }.
    to have_delivered_to(Community::EventsDelivery, :canceled, an_instance_of(event)).with(
      a_hash_including(profile: another_profile)
    ).and have_delivered_to(Community::EventsDelivery, :canceled, event).with(
      profile: profile
    )
end
```

If you want to test that no notification is deliver you can use negation:

```ruby
specify "when event is not found" do
  expect do
    described_class.perform_now(profile.id, "123", "one_hour_before")
  end.not_to have_delivered_to(Community::EventsDelivery)
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/active_delivery.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

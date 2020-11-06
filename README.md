[![Gem Version](https://badge.fury.io/rb/active_delivery.svg)](https://badge.fury.io/rb/active_delivery)
![Build](https://github.com/palkan/active_delivery/workflows/Build/badge.svg)
![JRuby Build](https://github.com/palkan/active_delivery/workflows/JRuby%20Build/badge.svg)

# Active Delivery

Framework providing an entry point (single _interface_) for all types of notifications: mailers, push notifications, whatever you want.

📖 Read the introduction post: ["Crafting user notifications in Rails with Active Delivery"](https://evilmartians.com/chronicles/crafting-user-notifications-in-rails-with-active-delivery)

<a href="https://evilmartians.com/?utm_source=action_policy">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

Requirements:

- Ruby ~> 2.5

**NOTE**: although most of the examples in this readme are Rails-specific, this gem could be used without Rails/ActiveSupport.

## The problem

We need a way to handle different notifications _channel_ (mail, push) in one place.

From the business-logic point of view we want to _notify_ a user, hence we need a _separate abstraction layer_ as an entry point to different types of notifications.

## The solution

Here comes _Active Delivery_.

In the simplest case when we have only mailers Active Delivery is just a wrapper for Mailer with (possibly) some additional logic provided (e.g., preventing emails to unsubscribed users).

Motivations behind Active Delivery:

- Organize notifications related logic:

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

- Better testability (see [Testing](#testing)).

## Installation

Add this line to your application's Gemfile:

```ruby
gem "active_delivery"
```

And then execute:

```sh
bundle
```

## Usage

The _Delivery_ class is used to trigger notifications. It describes how to notify a user (e.g., via email or push notification or both):

```ruby
class PostsDelivery < ActiveDelivery::Base
  # in most cases you don't have to specify anything in this class,
  # 'cause default transport-level classes (such as mailers)
end
```

It acts as a proxy in front of the different delivery channels (i.e., mailers, notifiers). That means that calling a method on delivery class invokes the same method on the corresponding _sender_ class, e.g.:

```ruby
PostsDelivery.notify(:published, user, post)

# under the hood it calls
PostsMailer.published(user, post).deliver_later

# and if you have a notifier (or any other line, see below)
PostsNotifier.published(user, post).notify_later
```

P.S. Naming ("delivery") is inspired by Basecamp: https://www.youtube.com/watch?v=m1jOWu7woKM.

**NOTE**: You could specify Mailer class explicitly or by custom pattern, using resolver:

```ruby
class PostsDelivery < ActiveDelivery::Base
  register_line :custom_mailer, ActiveDelivery::Lines::Mailer, resolver: ->(name) { CustomMailer }
end
```

Delivery also supports _parameterized_ calling:

```ruby
PostsDelivery.with(user: user).notify(:published, post)
```

The parameters could be accessed through the `params` instance method (e.g., to implement guard-like logic).

**NOTE**: When params are presents the parameterized mailer is used, i.e.:

```ruby
PostsMailer.with(user: user).published(post)
```

See [Rails docs](https://api.rubyonrails.org/classes/ActionMailer/Parameterized.html) for more information on parameterized mailers.

## Callbacks support

**NOTE:** callbacks are only available if ActiveSupport is present in the app's runtime.

```ruby
# Run method before delivering notification
# NOTE: when `false` is returned the execution is halted
before_notify :do_something

# You can specify a notification line (to run callback only for that line)
before_notify :do_mail_something, on: :mailer

# You can specify a notification name (to run callback only for specific notification)
after_notify :mark_user_as_notified, only: %i[user_reminder]

# if and unless options are also at your disposal
after_notify :mark_user_as_notified, if: -> { params[:user].present? }

# after_ and around_ callbacks are also supported
after_notify :cleanup

around_notify :set_context
```

Example:

```ruby
# Let's log notifications
class MyDelivery < ActiveDelivery::Base
  after_notify do
    # You can access the notificaion name within the instance
    MyLogger.info "Delivery triggered: #{notification_name}"
  end
end

MyDeliver.notify(:something_wicked_this_way_comes)
#=> Delivery triggered: something_wicked_this_way_comes
```

## Testing

**NOTE:** RSpec only for the time being.

Active Delivery provides an elegant way to test deliveries in your code (i.e., when you want to check whether a notification has been sent) through a `have_delivered_to` matcher:

```ruby
it "delivers notification" do
  expect { subject }.to have_delivered_to(Community::EventsDelivery, :modified, event)
    .with(profile: profile)
end
```

You can also use such RSpec features as [compound expectations](https://relishapp.com/rspec/rspec-expectations/docs/compound-expectations) and [composed matchers](https://relishapp.com/rspec/rspec-expectations/v/3-8/docs/composing-matchers):

```ruby
it "delivers to RSVPed members via .notify" do
  expect { subject }
    .to have_delivered_to(Community::EventsDelivery, :canceled, an_instance_of(event)).with(
      a_hash_including(profile: another_profile)
    ).and have_delivered_to(Community::EventsDelivery, :canceled, event).with(
      profile: profile
    )
end
```

If you want to test that no notification is delivered you can use negation

```ruby
specify "when event is not found" do
  expect do
    described_class.perform_now(profile.id, "123", "one_hour_before")
  end.not_to have_delivered_to(Community::EventsDelivery)
end
```

or use matcher

```ruby
specify "when event is not found" do
  expect do
    described_class.perform_now(profile.id, "123", "one_hour_before")
  end.to have_not_delivered_to(Community::EventsDelivery)
end
```

**NOTE:** test mode activated automatically if `RAILS_ENV` or `RACK_ENV` env variable is equal to "test". Otherwise add `require "active_delivery/testing/rspec"` to your `spec_helper.rb` / `rails_helper.rb` manually. This is also required if you're using Spring in test environment (e.g. with help of [spring-commands-rspec](https://github.com/jonleighton/spring-commands-rspec)).

## Custom "lines"

The _Line_ class describes the way you want to _transfer_ your deliveries.

We only provide only Action Mailer _line_ out-of-the-box.

A line connects _delivery_ to the _sender_ class responsible for sending notifications.

If you want to use parameterized deliveries, your _sender_ class must respond to `.with(params)` method.

Assume that we want to send messages via _pigeons_ and we have the following sender class:

```ruby
class EventPigeon
  class << self
    # Add `.with`  method as an alias
    alias with new

    # delegate delivery action to the instance
    def message_arrived(*args)
      new.message_arrived(*args)
    end
  end

  def initialize(params = {})
    # do smth with params
  end

  def message_arrived(msg)
    # send a pigeon with the message
  end
end
```

Now we want to add a _pigeon_ line to our `EventDelivery,` that is we want to send pigeons when
we call `EventDelivery.notify(:message_arrived, "ping-pong!")`.

Line class has the following API:

```ruby
class PigeonLine < ActiveDelivery::Lines::Base
  # This method is used to infer sender class
  # `name` is the name of the delivery class
  def resolve_class(name)
    name.gsub(/Delivery$/, "Pigeon").safe_constantize
  end

  # This method should return true if the sender recognizes the delivery action
  def notify?(delivery_action)
    # `handler_class` is available within the line instance
    sender_class.respond_to?(delivery_action)
  end

  # Called when we want to send message synchronously
  # `sender` here either `sender_class` or `sender_class.with(params)`
  # if params passed.
  def notify_now(sender, delivery_action, *args, **kwargs)
    # For example, our EventPigeon class returns some `Pigeon` object
    pigeon = sender.public_send(delivery_action, *args, **kwargs)
    # PigeonLaunchService do all the sending job
    PigeonService.launch pigeon
  end

  # Called when we want to send a message asynchronously.
  # For example, you can use a background job here.
  def notify_later(sender, delivery_action, *args, **kwargs)
    pigeon = sender.public_send(delivery_action, *args, **kwargs)
    # PigeonLaunchService do all the sending job
    PigeonLaunchJob.perform_later pigeon
  end
end
```

In case of parameterized calling, some update needs to be done on the new Line. Here is an example:

```ruby
class EventPigeon
  attr_reader :params

  class << self
    # Add `.with`  method as an alias
    alias with new

    # delegate delivery action to the instance
    def message_arrived(*args)
      new.message_arrived(*args)
    end
  end

  def initialize(params = {})
    @params = params
    # do smth with params
  end

  def message_arrived(msg)
    # send a pigeon with the message
  end
end

class PigeonLine < ActiveDelivery::Lines::Base
  def notify_later(sender, delivery_action, *args, **kwargs)
    # `to_s` is important for serialization. Unless you might have error
    PigeonLaunchJob.perform_later sender.class.to_s, delivery_action, *args, **kwargs.merge(params: line.params)
  end
end

class PigeonLaunchJob < ActiveJob::Base
  def perform(sender, delivery_action, *args, params: nil, **kwargs)
    klass = sender.safe_constantize
    handler = params ? klass.with(**params) : klass.new

    handler.public_send(delivery_action, *args, **kwargs)
  end
end
```

**NOTE**: we fallback to superclass's sender class if `resolve_class` returns nil.
You can disable automatic inference of sender classes by marking delivery as _abstract_:

```ruby
# we don't want to use ApplicationMailer by default, don't we?
class ApplicationDelivery < ActiveDelivery::Base
  self.abstract_class = true
end
```

The final step is to register the line within your delivery class:

```ruby
class EventDelivery < ActiveDelivery::Base
  # under the hood a new instance of PigeonLine is created
  # and used to send pigeons!
  register_line :pigeon, PigeonLine

  # you can pass additional options to customize your line
  # (and use multiple pigeons lines with different configuration)
  #
  # register_line :pigeon, PigeonLine, namespace: "AngryPigeons"
  #
  # now you can explicitly specify pigeon class
  # pigeon MyCustomPigeon
  #
  # or define pigeon specific callbacks
  #
  # before_notify :ensure_pigeon_is_not_dead, on: :pigeon
end
```

You can also _unregister_ a line.  For example, when subclassing another `Delivery` class or to remove any of the automatically added lines (e.g., `mailer`):

```ruby
class NonMailerDelivery < ActiveDelivery::Base
  # Use unregister_line to remove any default or inherited lines
  unregister_line :mailer
end
```

## Related projects

- [`abstract_notifier`](https://github.com/palkan/abstract_notifier) – Action Mailer-like interface for text-based notifications.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/active_delivery.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

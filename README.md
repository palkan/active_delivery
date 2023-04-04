[![Gem Version](https://badge.fury.io/rb/active_delivery.svg)](https://badge.fury.io/rb/active_delivery)
![Build](https://github.com/palkan/active_delivery/workflows/Build/badge.svg)
![JRuby Build](https://github.com/palkan/active_delivery/workflows/JRuby%20Build/badge.svg)

# Active Delivery

Active Delivery is a framework providing an entry point (single _interface_ or _abstraction_) for all types of notifications: mailers, push notifications, whatever you want.

📖 Read the introduction post: ["Crafting user notifications in Rails with Active Delivery"](https://evilmartians.com/chronicles/crafting-user-notifications-in-rails-with-active-delivery)

<a href="https://evilmartians.com/?utm_source=action_policy">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

Requirements:

- Ruby ~> 2.7
- Rails 6+ (optional).

**NOTE**: although most of the examples in this readme are Rails-specific, this gem could be used without Rails/ActiveSupport.

## The problem

We need a way to handle different notifications _channel_ (mail, push) in one place.

From the business-logic point of view, we want to _notify_ a user, hence we need a _separate abstraction layer_ as an entry point to different types of notifications.

## The solution

Here comes _Active Delivery_.

In the simplest case when we have only mailers Active Delivery is just a wrapper for Mailer with (possibly) some additional logic provided (e.g., preventing emails to unsubscribed users).

Motivations behind Active Delivery:

- Organize notifications-related logic:

```ruby
# Before
def after_some_action
  MyMailer.with(user: user).some_action(resource).deliver_later if user.receive_emails?
  NotifyService.send_notification(user, "action") if whatever_else?
end

# After
def after_some_action
  MyDelivery.with(user: user).some_action(resource).deliver_later
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
bundle install
```

## Usage

The _Delivery_ class is used to trigger notifications. It describes how to notify a user (e.g., via email or push notification or both).

First, it's recommended to create a base class for all deliveries with the configuration of the lines:

```ruby
# In the base class, you configure delivery lines
class ApplicationDelivery < ActiveDelivery::Base
  self.abstract_class = true

  # Mailers are enabled by default, everything else must be declared explicitly

  # For example, you can use a notifier line (see below) with a custom resolver
  register_line :sms, ActiveDelivery::Lines::Notifier,
    resolver: -> { _1.name.gsub(/Delivery$/, "SMSNotifier").safe_constantize }

  register_line :cable, ActionCableDeliveryLine
  # and more
end
```

Then, you can create a delivery class for a specific notification type. We follow Action Mailer conventions, and create a delivery class per resource:

```ruby
class PostsDelivery < ApplicationDelivery
end
```

In most cases, you just leave this class blank. The corresponding mailers, notifiers, etc., will be inferred automatically using the naming convention.

You don't need to define notification methods explicitly. Whenever you invoke a method on a delivery class, it will be proxied to the underlying _line handlers_ (mailers, notifiers, etc.):

```ruby
PostsDelivery.published(user, post).deliver_later

# Under the hood it calls
PostsMailer.published(user, post).deliver_later
PostsSMSNotifier.published(user, post).notify_later

# and whaterver your ActionCableDeliveryLine does
# under the hood.
```

Alternatively, you call the `#notify` method with the notification name and the arguments:

```ruby
PostsDelivery.notify(:published, user, post)

# Under the hood it calls
PostsMailer.published(user, post).deliver_later
PostsSMSNotifier.published(user, post).notify_later
# ...
```

You can also define a notification method explicitly if you want to add some logic:

```ruby
class PostsDelivery < ApplicationDelivery
  def published(user, post)
    # do something

    # return a delivery object (to chain #deliver_later, etc.)
    delivery(
      notification: :published,
      params: [user, post],
      # For kwargs, you options
      options: {},
      # Metadata that can be used by line handlers
      metadata: {}
    )
  end
end
```

Finally, you can disable the default automatic proxying behaviour via the `ActiveDelivery.deliver_actions_required = true` configuration option. Then, in each delivery class, you can specify the available actions via the `.delivers` method:

```ruby
class PostDelivery < ApplicationDelivery
  delivers :published
end

ActiveDelivery.deliver_actions_required = true

PostDelivery.published(post) #=> ok
PostDelivery.whatever(post) #=> raises NoMethodError
```

### Customizing delivery handlers

You can specify a mailer class explicitly:

```ruby
class PostsDelivery < ActiveDelivery::Base
  # You can pass a class name or a class itself
  mailer "CustomPostsMailer"
  # For other lines, you the line name as well
  # sms "MyPostsSMSNotifier"
end
```

Or you can provide a custom resolver by re-registering the line:

```ruby
class PostsDelivery < ActiveDelivery::Base
  register_line :mailer, ActiveDelivery::Lines::Mailer, resolver: ->(_delivery_class) { CustomMailer }
end
```

### Parameterized deliveries

Delivery also supports _parameterized_ calling:

```ruby
PostsDelivery.with(user: user).notify(:published, post)
```

The parameters could be accessed through the `params` instance method (e.g., to implement guard-like logic).

**NOTE**: When params are present, the parameterized mailer is used, i.e.:

```ruby
PostsMailer.with(user: user).published(post)
```

Other line implementations **MUST** also have the `#with` method in their public interface.

See [Rails docs](https://api.rubyonrails.org/classes/ActionMailer/Parameterized.html) for more information on parameterized mailers.

### Callbacks support

**NOTE:** callbacks are only available if ActiveSupport is present in the application's runtime.

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

# You can also skip callbacks in sub-classes
skip_before_notify :do_something, only: %i[some_reminder]

# NOTE: Specify `on` option for line-specific callbacks is required to skip them
skip_after_notify :do_mail_something, on: :mailer
```

Example:

```ruby
# Let's log notifications
class MyDelivery < ActiveDelivery::Base
  after_notify do
    # You can access the notification name within the instance
    MyLogger.info "Delivery triggered: #{notification_name}"
  end
end

MyDeliver.notify(:something_wicked_this_way_comes)
#=> Delivery triggered: something_wicked_this_way_comes
```

## Testing

**NOTE:** Currently, only RSpec matchers are provided.

### Deliveries

Active Delivery provides an elegant way to test deliveries in your code (i.e., when you want to check whether a notification has been sent) through a `have_delivered_to` matcher:

```ruby
it "delivers notification" do
  expect { subject }.to have_delivered_to(Community::EventsDelivery, :modified, event)
    .with(profile: profile)
end
```

You can also use such RSpec features as compound expectations and composed matchers:

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

or use the `#have_not_delivered_to` matcher:

```ruby
specify "when event is not found" do
  expect do
    described_class.perform_now(profile.id, "123", "one_hour_before")
  end.to have_not_delivered_to(Community::EventsDelivery)
end
```

### Delivery classes

You can test Delivery classes as regular Ruby classes:

```ruby
describe PostsDelivery do
  let(:user) { build_stubbed(:user) }
  let(:post) { build_stubbed(:post) }

  describe "#published" do
    it "sends a mail" do
      expect {
        described_class.published(user, post).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("New post published")
    end
  end
end
```

You can also use the `#deliver_via` matchers as follows:

```ruby
describe PostsDelivery, type: :delivery do
  let(:user) { build_stubbed(:user) }
  let(:post) { build_stubbed(:post) }

  describe "#published" do
    it "delivers to mailer and sms" do
      expect {
        described_class.published(user, post).deliver_later
      }.to deliver_via(:mailer, :sms)
    end

    context "when user is not subscribed to SMS notifications" do
      let(:user) { build_stubbed(:user, sms_notifications: false) }

      it "delivers to mailer only" do
        expect {
          described_class.published(user, post).deliver_now
        }.to deliver_via(:mailer)
      end
    end
  end
end
```

**NOTE:** test mode activated automatically if `RAILS_ENV` or `RACK_ENV` env variable is equal to "test". Otherwise, add `require "active_delivery/testing/rspec"` to your `spec_helper.rb` / `rails_helper.rb` manually. This is also required if you're using Spring in the test environment (e.g. with help of [spring-commands-rspec](https://github.com/jonleighton/spring-commands-rspec)).

## Custom "lines"

The _Line_ class describes the way you want to _transfer_ your deliveries.

We only provide only Action Mailer _line_ out-of-the-box.

A line connects _delivery_ to the _sender_ class responsible for sending notifications.

If you want to use parameterized deliveries, your _sender_ class must respond to `.with(params)` method.

### A full-featured line example: pigeons 🐦

Assume that we want to send messages via _pigeons_ and we have the following sender class:

```ruby
class EventPigeon
  class << self
    # Add `.with`  method as an alias
    alias_method :with, :new

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

In the case of parameterized calling, some update needs to be done on the new Line. Here is an example:

```ruby
class EventPigeon
  attr_reader :params

  class << self
    # Add `.with`  method as an alias
    alias_method :with, :new

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

**NOTE**: we fall back to the superclass's sender class if `resolve_class` returns nil.
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
  # pigeon "MyCustomPigeon"
  #
  # or define pigeon specific callbacks
  #
  # before_notify :ensure_pigeon_is_not_dead, on: :pigeon
end
```

You can also _unregister_ a line:

```ruby
class NonMailerDelivery < ActiveDelivery::Base
  # Use unregister_line to remove any default or inherited lines
  unregister_line :mailer
end
```

### An example of a universal sender: Action Cable

Although Active Delivery is designed to work with Action Mailer-like abstraction, it's flexible enough to support other use cases.

For example, for some notification channels, we don't need to create a separate class for each resource or context; we can send the payload right to the communication channel. Let's consider an Action Cable line as an example.

For every delivery, we want to broadcast a message via Action Cable to the stream corresponding to the delivery class name. For example:

```ruby
# Our PostsDelivery example from the beginning
PostsDelivery.with(user:).notify(:published, post)

# Will results in the following Action Cable broadcast:
DeliveryChannel.broadcast_to user, {event: "posts.published", post_id: post.id}
```

The `ActionCableDeliveryLine` class can be implemented as follows:

```ruby
class ActionCableDeliveryLine < ActiveDelivery::Line::Base
  # Context is our universal sender.
  class Context
    attr_reader :user

    def initialize(scope)
      @scope = scope
    end

    # User is required for this line
    def with(user:, **)
      @user = user
      self
    end
  end

  # The result of this callback is passed further to the `notify_now` method
  def resolve_class(name)
    Context.new(name.sub(/Delivery$/, "").underscore)
  end

  # We want to broadcast all notifications
  def notify?(...) = true

  def notify_now(context, delivery_action, *args, **kwargs)
    # Skip if no user provided
    return unless context.user

    payload = {event: [context.scope, delivery_action].join(".")}
    payload.merge!(serialized_args(*args, **kwargs))

    DeliveryChannel.broadcast_to context.user, payload
  end

  # Broadcasts are asynchronous by nature, so we can just use `notify_now`
  alias_method :notify_later, :notify_now

  private

  def serialized_args(*args, **kwargs)
    # Code that convers AR objects into IDs, etc.
  end
end
```

## Related projects

- [`abstract_notifier`](https://github.com/palkan/abstract_notifier) – Action Mailer-like interface for text-based notifications.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/active_delivery.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

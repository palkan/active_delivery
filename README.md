# Active Delivery

Framework providing an entrypoint (single _interface_) for all types of notifications: mailers, push notifications, whatever you want.

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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/active_delivery.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

# Change log

## master

## 1.1.0 (2023-12-01) ❄️

- Support delayed delivery options (e.g, `wait_until`). ([@palkan][])

## 📬 1.0.0 (2023-08-29)

- Add `resolver_pattern` option to specify naming pattern for notifiers without using Procs. ([@palkan][])

- [!IMPORTANT] Notifier's `#notify_later` now do not process the action right away, only enqueue the job. ([@palkan][]).

  This matches the Action Mailer behaviour. Now, the action is only invoked before the delivery attempt.

- Add callbacks support to Abstract Notifier (`before_action`, `after_deliver`, etc.). ([@palkan][])

- **Merge in abstract_notifier** ([@palkan][])

  [Abstract Notifier](https://github.com/palkan/abstract_notifier) is now a part of Active Delivery.

- Add ability to specify delivery actions explicitly and disable implicit proxying. ([@palkan][])

  You can disable default Active Delivery behaviour of proxying action methods to underlying lines via the `ActiveDelivery.deliver_actions_required = true` configuration option. Then, in each delivery class, you can specify the available actions via the `.delivers` method:

  ```ruby
  class PostMailer < ApplicationMailer
    def published(post)
      # ...
    end

    def whatever(post)
      # ...
    end
  end

  ActiveDelivery.deliver_actions_required = true

  class PostDelivery < ApplicationDelivery
    delivers :published
  end

  PostDelivery.published(post) #=> ok
  PostDelivery.whatever(post) #=> raises NoMethodError
  ```

- Add `#deliver_via(*lines)` RSpec matcher. ([@palkan][])

- **BREAKING** The `#resolve_class` method in Line classes now receive a delivery class instead of a name:

  ```ruby
  # before
  def resolve_class(name)
    name.gsub(/Delivery$/, "Channel").safe_constantize
  end

  # after
  def resolve_class(name)
    name.to_s.gsub(/Delivery$/, "Channel").safe_constantize
  end
  ```

- Provide ActionMailer-like interface to trigger notifications. ([@palkan][])

  Now you can send notifications as follows:

  ```ruby
  MyDelivery.with(user:).new_notification(payload).deliver_later

  # Equals to the old (and still supported)
  MyDelivery.with(user:).notify(:new_notification, payload)
  ```

- Support passing a string class name as a handler class. ([@palkan][])

- Allow disabled handler classes cache and do not cache when Rails cache_classes is false. ([@palkan][])

- Add `skip_{before,around,after}_notify` support. ([@palkan][])

- Rails <6 is no longer supported.

- Ruby 2.7+ is required.

## 0.4.4 (2020-09-01)

- Added `ActiveDelivery::Base.unregister_line` ([@thornomad][])

## 0.4.3 (2020-08-21)

- Fix parameterized mailers support in Rails >= 5.0, <5.2 ([@dmitryzuev][])

## 0.4.2 (2020-04-28)

- Allow resolve mailer class with custom pattern ([@brovikov][])

## 0.4.1 (2020-04-22)

- Fixed TestDelivery fiber support. ([@pauldub](https://github.com/pauldub))

## 0.4.0 (2020-03-02)

- **Drop Ruby 2.4 support**. ([@palkan][])

- Allow passing keyword arguments to `notify`. ([@palkan][])

## 0.3.1 (2020-02-21)

- Fixed RSpec detection. ([@palkan][])

- Add note about usage with Spring. ([@iBublik][])

## 0.3.0 (2019-12-25)

- Add support of :only, :except params for callbacks. ([@curpeng][])

- Add negation rspec matcher: `have_not_delivered_to`. ([@StanisLove](https://github.com/stanislove))

- Improve RSpec matcher's failure message. ([@iBublik][])

## 0.2.1 (2018-01-15)

- Backport `ActionMailer::Paremeterized` for Rails <5. ([@palkan][])

## 0.2.0 (2018-01-11)

- Add `#notification_name`. ([@palkan][])

- Support anonymous callbacks. ([@palkan][])

## 0.1.0 (2018-12-20)

Initial version.

[@palkan]: https://github.com/palkan
[@curpeng]: https://github.com/curpeng
[@iBublik]: https://github.com/ibublik
[@brovikov]: https://github.com/brovikov
[@dmitryzuev]: https://github.com/dmitryzuev
[@thornomad]: https://github.com/thornomad

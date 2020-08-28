# Change log

## master

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

# README

## RUBY VERSION

Ruby 3.3.7
Rails 8.1.2


## SYSTEM DEPENDENCIES

Ruby (via asdf / rbenv / rvm)
SQLite (or your configured database)
Node.js (only if required for other tooling)
dartsass-rails for SCSS compilation


## CSS ARCHITECTURE (IMPORTANT)

This project uses:

gem "dartsass-rails", "~> 0.5.1"

We DO NOT use:

sass-rails
sassc-rails
cssbundling-rails
webpack / esbuild for CSS

CSS is compiled by Dart Sass via dartsass-rails.


## HOW CSS WORKS

### ENTRY POINT

Main stylesheet:

app/assets/stylesheets/application.scss

Compiled output:

app/assets/builds/application.css

⚠️ DO NOT MODIFY THE COMPILED FILE MANUALLY.


## RAILS LAYOUT REQUIREMENT

Layout must include:

<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>

Do NOT use:

<%= stylesheet_link_tag :app %>

Do NOT add additional stylesheet_link_tag entries for partial stylesheets.

All styles must be registered via application.scss.


## ADDING NEW STYLES

### STEP 1 — CREATE SCSS FILE

Example:

app/assets/stylesheets/dashboard.scss

### STEP 2 — REGISTER IT IN application.scss

Use modern Sass module system:

@use "dashboard";

Do NOT use @import (deprecated).


## @USE BEHAVIOR

If file contains only CSS:

.header { ... }

Works normally.

If file defines variables:

$primary: #7c3aed;

Variables become namespaced:

@use "dashboard";

.button {
  color: dashboard.$primary;
}


## SHARED VARIABLES

Create shared partial:

app/assets/stylesheets/_variables.scss

Use:

@use "variables";


## NAMING RULES

Use .scss extension for all styles.

Shared modules must start with _ :

_variables.scss
_mixins.scss

Do NOT create application.css.


## RUNNING THE APP (DEVELOPMENT)

Always use:

bin/dev

This starts:

Rails server
Dart Sass watcher

You should see:

css.1  | Sass is watching for changes.

Do NOT use:

rails s

CSS will not auto-compile.


## DATABASE SETUP

Preferred:

bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

Alternative (if needed):

bundle exec rails db:create
bundle exec rails db:migrate


bundle exec rails db:seed


## RUNNING TESTS

Run all tests:

bundle exec rspec

Run specific file:

bundle exec rspec spec/path_to/file_spec.rb


## PRODUCTION BUILD

Before deployment:

RAILS_ENV=production rails assets:precompile


## DO NOT

Do NOT edit app/assets/builds/application.css
Do NOT commit /public/assets
Do NOT use deprecated @import
Do NOT add extra stylesheet tags


## DEVELOPER SUMMARY

All styles go through application.scss
Use @use, not @import
Start app with bin/dev
Never edit compiled CSS
Keep styles modular

# Colorist Space — WayForPay у development

Це повний пакет файлів для встановлення поверх наданого коду, включно з попереднім етапом моделей. Він замінює стару реалізацію підписок на Subscription / SubscriptionPayment і містить контролер, webhook, керування регуляркою, UK/EN, в'ю, RSpec та цикл звірки. Початкову міграцію з попереднього архіву не змінено; додано другу міграцію.

**Статус перевірки:** Ruby-код і Ruby-частини ERB перевірені парсером, YAML прочитано, ключі UK/EN зіставлено. Контрольні HMAC значення перевірені незалежно через Python. Ruby/Bundler і повного Rails-проєкту тут немає: RSpec та рендер Rails не запускалися, реального платежу чи запиту до вашого merchant не виконувалось. Це пакет для інтеграційної перевірки в development, не підтверджена production-інтеграція.

## 1. Встановлення

Зупини `bin/dev` на час переходу. Скопіюй директорії `app`, `config`, `db`, `lib`, `spec`, `script` з архіву в проєкт зі збереженням структури. `config/routes.rb` відтворює всі надані маршрути та замінює лише секцію підписки. Якщо після надсилання коду ти змінював маршрути, перенеси лише цю секцію.

Включено повний `app/models/user.rb`: стара автентифікація збережена, логіка підписки винесена в `SubscriptionAccess`. Другий `has_one :subscription` вручну додавати не потрібно. У concern новий користувач отримує 7-денний trial; OAuth також проходить модельний callback. Existing users переносяться імпортом без перезапуску trial.

```bash
bin/rails db:migrate
bin/rails subscriptions:import_legacy
bin/rails zeitwerk:check
```

Якщо першу міграцію ти вже застосував, Rails виконає лише другу. Якщо перейменовував timestamp першої міграції, залиш свій застосований файл і не копіюй його дубль із архіву. `db/schema.rb` генерується Rails; старі User-колонки поки не видаляємо.

Видали старий `app/views/subscriptions/payment_form.html.erb`, якщо він є. Маршрут `wayforpay_subscription_path` видалений; жодна нова в'ю його не використовує.

Підключи `subscription_integration.css` у спосіб, який уже використовує твій `application.css`: автоматичне підключення всіх stylesheet-файлів або CSS `@import "subscription_integration.css";` на початку. Він доповнює попередні settings-стилі. Якщо існуючі правила `.subscription-header .back` використовують absolute positioning, додатковий файл має завантажуватися після них (у новому файлі це скинуто).

Пошукай інші читання старих полів:

```bash
rg 'plan_name|subscription_expires_at' app spec
```

Нові в'ю використовують `subscription_plan` і `subscription.current_period_end`. Неперенесені старі сторінки читатимуть застарілий User snapshot. Не записуй нові оплати в User-колонки. `ImportLegacy` використовує читання колонок напряму та не переписує записи з source=wayforpay.

## 2. Development credentials

```bash
EDITOR="code --wait" bin/rails credentials:edit --environment development
```

Приклад для початкової перевірки Purchase з **публічними демо-реквізитами WayForPay**:

```yaml
wayforpay:
  demo: true
  merchant_account: test_merch_n1
  secret_key: "flk3409refn54t54t*FNJRET"
  merchant_password: ""
  merchant_domain: dev.colorist.space
  public_base_url: https://dev.colorist.space
  monthly_amount_minor: 100
  yearly_amount_minor: 1000
```

`100` копійок = 1 UAH, `1000` = 10 UAH. Усі ціни читаються з конфігурації та фіксуються у замовленні; зміна конфігурації не змінює вже підписані checkout-и.

**Демо Purchase і повна перевірка регулярки — різні перевірки.** Офіційна сторінка тестових реквізитів публікує account/secret для Purchase; вона не гарантує доступ до регулярних операцій цими реквізитами. Для `STATUS`, `CHANGE`, `REMOVE` потрібний придатний для тестового merchant `merchantPassword`. Отримай його для відповідного merchant у WayForPay/їхній підтримці; це не копія secret_key і не пароль входу, який слід вгадувати. У пакет не вставлений випадковий пароль із прикладу API.

Поки merchant_password порожній, можна перевірити Purchase та підписаний callback, але звірка регулярки покаже помилку конфігурації, а автопродовження залишиться непідтвердженим. Немає локального обходу, який перетворює таку помилку на успіх.

Не використовуй надісланий раніше особистий secret повторно, якщо він був справжнім приватним ключем. Для свого тестового merchant встанови його актуальні власні реквізити й домен. `demo: true` лише маркує UI; він сам не переводить реальний merchant у sandbox і не зупиняє реальні списання. Використовуй тестовий merchant/дозволений ним спосіб тестування.

Можна використовувати ENV замість credentials, наприклад `WAYFORPAY_MERCHANT_ACCOUNT`, `WAYFORPAY_SECRET_KEY`, `WAYFORPAY_MERCHANT_PASSWORD`, `WAYFORPAY_PUBLIC_BASE_URL`, `WAYFORPAY_MERCHANT_DOMAIN`, `WAYFORPAY_MONTHLY_AMOUNT_MINOR`, `WAYFORPAY_YEARLY_AMOUNT_MINOR`, `WAYFORPAY_DEMO`. ENV має пріоритет.

## 3. Cloudflare та запуск

В окремих терміналах:

```bash
bin/dev
```

```bash
cloudflared tunnel run colorist-dev
```

```bash
bin/rails runner script/wayforpay_reconcile.rb
```

Третій процес раз на хвилину **читає** стан платежів; він не ініціює списання. Списує WayForPay за власним графіком. Зупинка — Ctrl-C. Це явний development-процес, він не був запущений або встановлений автоматично.

Callback:

```text
POST https://dev.colorist.space/subscription/payment_callback
```

Ця адреса не потребує Devise-сесії, modern browser або Rails CSRF token. Підпис та merchant перевіряються перед записом/активацією. JSON підтримується також у raw body з form content type. Не став Cloudflare Access login/challenge перед callback-ом. Якщо Rails блокує хост, додай у development-конфігурацію `config.hosts << "dev.colorist.space"`.

Повернення браузера:

```text
GET/POST https://dev.colorist.space/subscription/payment_return
```

Повернення лише веде на settings і ніколи не активує доступ. Результат може надійти трохи пізніше; є кнопка «Перевірити статус оплати».

## 4. Що робить інтеграція

- Checkout створює SubscriptionPayment до переходу на провайдера й фіксує plan, amount, period, reference та підписану форму. Повторний клік у межах 15 хвилин повертає той самий order.
- Прострочений checkout замінюється лише після CHECK_STATUS: таймаут/платіж в обробці не дозволяє створити новий order. CHECK_STATUS може повернути Order Not Found для ще не надісланої форми. Це приймається тільки від фіксованого HTTPS API, не з callback-а.
- Активний оплачений доступ блокує створення другої регулярки. Після cancel можна оформити нову після завершення оплаченого періоду. Історія старої оплати лишається.
- Callback перевіряє HMAC-MD5, merchant, збережений order, суму, валюту. Визначення користувача через email видалене. Застосування першої оплати й processed_at відбуваються під транзакцією та блокуванням Subscription.
- Повторна подія не додає ще один період. Відповідь — підписаний JSON accept.
- Approved активує оплачений доступ. Автопродовження стає підтвердженим лише після STATUS=Active з очікуваними параметрами регулярки.
- Cancel викликає REMOVE. Оплачений current_period_end залишається. Перед remote операцією зберігається management_intent; повторний cancel ремонтує локальний стан, якщо REMOVE раніше вже відбувся.
- CHANGE фіксує next_plan / next_amount_minor на наступний період, не переписує вже оплачений plan. Повторна спроба повторює той самий абсолютний графік. Помилка remote операції не вважається локальним успіхом.
- В'ю показують ціну, статус, майбутній тариф, стан автопродовження та останні 20 оплат; усі нові тексти є UK/EN.
- Superadmin отримує доступ незалежно від підписки; платіжні екшени для нього заблоковані також на сервері.

## 5. Як саме обробляються повторні списання

У відкритій документації не вистачає однозначного правила зв'язку callback orderReference кожного повторного списання з початковою угодою. Тут **немає вгадування префіксів або email**.

Повторні періоди підтверджує `regularApi STATUS` за точно збереженим кореневим reference: перевіряються status, mode, amount, currency, lastPayedStatus, lastPayedDate, nextPaymentDate. Новий підтверджений період застосовується один раз. Помилка/невідомий формат/невідповідна сума не подовжує доступ.

Квитанція такого підтвердження має `source: regular_status`. Її `order_reference` з префіксом `status/` — **внутрішній ключ звірки**, не вигаданий transaction ID WayForPay. UI позначає джерело. STATUS повертає останню оплату, тому після довгої зупинки він може відновити поточний доступ, але **не відтворить кожне пропущене списання**. Для повного фінансового журналу потрібні merchant-specific callback fixtures/експорт транзакцій і перевірене правило зіставлення; ця частина ще не підтверджена живими даними.

Невідомі callback-и з валідним підписом зберігаються у WayforpayEvent зі state=unmatched та підтверджуються після збереження. Це не означає, що вони прив'язані до користувача або самі надали доступ. Їхню кількість показує rake task. Metadata обмежена allowlist; токени картки, секрети й повний payload не зберігаються.

```bash
bin/rails wayforpay:reconcile
```

Після реального тестового повторного списання перевір одночасно `Subscription.current_period_end`, квитанцію regular_status і отриманий callback. Це необхідна перевірка, а не вже доведена можливість тестового merchant.

Refund/chargeback після вже застосованої оплати не відкочує доступ автоматично в цьому пакеті. Це потребує окремої політики перерахунку періодів і обробки повернень; callback-и зберігаються, повторного доступу не надають. Видалення акаунта з платіжною історією/угодою блокується з поясненням. Акаунт лише з trial без оплат можна видалити через Devise. Автоматичну анонімізацію фінансової історії тут не реалізовано.

## 6. Тести

```bash
bundle exec rspec spec/requests/subscriptions_spec.rb \
  spec/models/subscription_spec.rb \
  spec/models/subscription_payment_spec.rb \
  spec/models/user_subscription_access_spec.rb \
  spec/services/subscriptions \
  spec/services/wayforpay
```

Пакет включає оновлену User factory та заміну старого subscriptions request spec. Existing User spec можна залишити: успадковані поля на створенні підтримані для legacy-fixtures. Надалі після create змінюй Subscription, не User.plan_name.

```ruby
user.subscription.update!(
  plan: "monthly",
  current_period_start: Time.current,
  current_period_end: 1.month.from_now
)
```

У нових specs мережеві операції management/reconciliation замокані, а callback підписується тестовим ключем; це не реальні платежі. Перевіряються повтори, неправильний merchant/amount/signature, чужий email, невідомий reference, server callback без входу, API failure, повторний cancel, зміна плану та звірка періодів. Ці RSpec-сценарії підготовлені, але тут не виконані.

## 7. Перевірка через браузер

1. Звичайний користувач (не superadmin) → Налаштування → Підписка.
2. Обрати місячний тариф → на checkout побачити 1 UAH і умови автопродовження.
3. Пройти дозволену тестовим merchant оплату. Перевірити callback=200 із accept та активований period.
4. Перевірити статус: за доступного regularApi має підтвердитися Active. Без merchantPassword тут буде реальна помилка, а не показовий успіх.
5. Змінити на річний: plan ще monthly, next_plan=yearly, графік провайдера — з наступного періоду.
6. Скасувати: провайдер Removed, auto_renew=false, current_period_end не змінився.
7. Окремою тестовою угодою перевірити повторне списання та звірку. Не змінюй дати продакшн-угоди заради прискорення тесту.

## 8. Перед production

Окремі production credentials, production merchant, ціни та public_base_url. Перенесення не зводиться лише до заміни двох рядків: тестові угоди не належать production merchant. Заверши тестові регулярки під їхніми старими credentials, потім використай чисті production-дані/явне перенесення доступу. Production не приймає конфігурацію з demo=true або публічним test_merch_n1.

Для production заміни foreground development-loop на штатний планувальник/worker, налаштуй моніторинг unmatched/failed events та підтвердь журнал кожного recurring платежу живими fixtures. Timeout-и bounded; жодна зовнішня помилка не підміняється успішним скасуванням.

Джерела протоколу (перевірено 22.09.2026):
- https://wiki.wayforpay.com/view/852102
- https://wiki.wayforpay.com/view/852117
- https://wiki.wayforpay.com/view/852472
- https://wiki.wayforpay.com/view/852526
- https://wiki.wayforpay.com/view/13271051
- https://wiki.wayforpay.com/view/852521
- https://wiki.wayforpay.com/view/852131

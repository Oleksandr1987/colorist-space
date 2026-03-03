# README

## RUBY VERSION

Ruby 3.2.6  
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
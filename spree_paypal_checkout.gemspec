# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_paypal_checkout/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_paypal_checkout'
  s.version     = SpreePaypalCheckout::VERSION
  s.summary     = "Spree Commerce PayPal Checkout payment gateway integration"
  s.required_ruby_version = '>= 3.0'

  s.author    = 'Vendo Connect Inc.'
  s.email     = 'hello@spreecommerce.org'
  s.homepage  = 'https://github.com/spree/spree_paypal_checkout'
  s.license = 'AGPL-3.0-or-later'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  spree_opts = '>= 5.1.0.beta4'
  s.add_dependency 'spree', spree_opts
  s.add_dependency 'spree_storefront', spree_opts
  s.add_dependency 'spree_admin', spree_opts
  s.add_dependency 'spree_extension'

  s.add_dependency 'paypal-server-sdk', '~> 1.1'

  s.add_development_dependency 'dotenv'
  s.add_development_dependency 'spree_dev_tools'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
end

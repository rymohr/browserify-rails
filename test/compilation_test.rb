require "test_helper"

class BrowserifyTest < ActionController::IntegrationTest
  setup do
    Rails.application.assets.cache = nil

    FileUtils.cp(File.join(Rails.root, "app/assets/javascripts/application.js.example"), File.join(Rails.root, "app/assets/javascripts/application.js"))
    FileUtils.cp(File.join(Rails.root, "app/assets/javascripts/foo.js.example"), File.join(Rails.root, "app/assets/javascripts/foo.js"))
    FileUtils.cp(File.join(Rails.root, "app/assets/javascripts/nested/index.js.example"), File.join(Rails.root, "app/assets/javascripts/nested/index.js"))
    FileUtils.cp(File.join(Rails.root, "app/assets/javascripts/mocha.js.coffee.example"), File.join(Rails.root, "app/assets/javascripts/mocha.js.coffee"))
    FileUtils.cp(File.join(Rails.root, "app/assets/javascripts/coffee.js.coffee.example"), File.join(Rails.root, "app/assets/javascripts/coffee.js.coffee"))
    FileUtils.cp(File.join(Rails.root, "app/assets/javascripts/browserified.js.example"), File.join(Rails.root, "app/assets/javascripts/browserified.js"))
  end

  test "asset pipeline should serve application.js" do
    expected_output = fixture("application.out.js")

    get "/assets/application.js"
    assert_response :success
    assert_equal expected_output, @response.body.strip
  end

  test "asset pipeline should serve foo.js" do
    expected_output = fixture("foo.out.js")

    get "/assets/foo.js"
    assert_response :success
    assert_equal expected_output, @response.body.strip
  end

  test "asset pipeline should regenerate application.js when foo.js changes" do
    expected_output = fixture("application.out.js")

    get "/assets/application.js"
    assert_response :success
    assert_equal expected_output, @response.body.strip

    # Ensure that Sprockets can detect the change to the file modification time
    sleep 1

    File.open(File.join(Rails.root, "app/assets/javascripts/foo.js"), "w+") do |f|
      f.puts "require('./nested');"
      f.puts "module.exports = function (n) { return n * 12 }"
    end

    expected_output = fixture("application.foo_changed.out.js")

    get "/assets/application.js"
    assert_response :success
    assert_equal expected_output, @response.body.strip
  end

  test "asset pipeline should regenerate application.js when application.js changes" do
    expected_output = fixture("application.out.js")

    get "/assets/application.js"
    assert_response :success
    assert_equal expected_output, @response.body.strip

    # Ensure that Sprockets can detect the change to the file modification time
    sleep 1

    File.open(File.join(Rails.root, "app/assets/javascripts/application.js"), "w+") do |f|
      f.puts "var foo = require('./foo');"
      f.puts "console.log(foo(11));"
    end

    expected_output = fixture("application.changed.out.js")

    get "/assets/application.js"
    assert_response :success
    assert_equal expected_output, @response.body.strip
  end

  test "browserifies coffee files after they have been compiled to JS" do
    expected_output = fixture("mocha.js")

    get "/assets/mocha.js"

    assert_response :success
    assert_equal expected_output, @response.body.strip
  end

  test "browserifies files with coffee requires" do
    get "/assets/coffee.js"
    assert_no_match /BrowserifyRails::BrowserifyError/, @response.body
  end

  test "skips files that are already browserified" do
    get "/assets/browserified.js"
    assert_equal fixture("browserified.js"), @response.body.strip
  end

  test "throws BrowserifyError if something went wrong while executing browserify" do
    File.open(File.join(Rails.root, "app/assets/javascripts/application.js"), "w+") do |f|
      f.puts "var foo = require('./foo');"
      f.puts "var bar = require('./bar');"
    end

    get "/assets/application.js"
    assert_match /BrowserifyRails::BrowserifyError/, @response.body
  end
end

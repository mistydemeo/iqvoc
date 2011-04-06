require 'test_helper'
require 'integration_test_helper'


class SearchTest < ActionDispatch::IntegrationTest

  setup do
    password = "FooBar"
    # create an editor user
    editor = User.new(:forename => "John", :surname => "Doe",
        :email => "foo@example.org",
        :password => password, :password_confirmation => password,
        :active => true, :role => "editor")
    editor.save
    # create an admin user
    admin = User.new(:forename => "Jane", :surname => "Doe",
        :email => "bar@example.org",
        :password => password, :password_confirmation => password,
        :active => true, :role => "administrator")
    admin.save

    # create a few XL labels
    labels = {}
    {
      "terra" => "la",
      "earth" => "en",
      "Erde" => "de",
      "sol" => "la",
      "sun" => "en",
      "Sonne" => "de",
      "inhabited" => "en",
      "bewohnt" => "de",
      "uninhabited" => "en",
      "unbewohnt" => "de"
    }.map { |name, lang|
      label = Iqvoc::XLLabel.base_class.create(:origin => "_%s" % name,
          :value => name, :language => lang, :published_at => Time.now)
      labels[name] = label
    }

    # create a few concepts
    [
      ["Erde", "earth"],
      ["Sonne", "sun"]
    ].each { |pref, alt|
        concept = Iqvoc::Concept.base_class.create(:origin => "_%s" % pref,
            :published_at => Time.now)
        labeling = Labeling::SKOSXL::PrefLabel.create(
            :owner => concept, :target => labels[pref])
        labeling = Labeling::SKOSXL::AltLabel.create(
            :owner => concept, :target => labels[alt])
    }

    # create a few collections
    [
      ["bewohnt", "inhabited"],
      ["unbewohnt", "uninhabited"]
    ].each { |pref, alt|
        collection = Iqvoc::Collection.base_class.create
        labeling = Labeling::SKOSXL::PrefLabel.create(
            :owner => collection, :target => labels[pref])
        labeling = Labeling::SKOSXL::AltLabel.create(
            :owner => collection, :target => labels[alt])
    }

    # confirm environment, just to be safe
    assert_equal 2, User.all.count
    assert_equal 10, Label::Base.all.count
    assert_equal 8, Labeling::Base.all.count
    assert_equal 2, Iqvoc::Concept.base_class.all.count
    assert_equal 2, Iqvoc::Collection.base_class.all.count
    assert_equal 4, Concept::Base.all.count

    # provide auth headers -- XXX: unused?
    @env = {}
    auth = Base64::encode64("%s:%s" % [editor.email, editor.password])
    @env[:editor] = { "HTTP_AUTHORIZATION" => "Basic " + auth }
    auth = Base64::encode64("%s:%s" % [admin.email, admin.password])
    @env[:admin] = { "HTTP_AUTHORIZATION" => "Basic " + auth }
  end

  test "HTML search returns matches" do
    uri = search_path(:lang => "de", :format => "html")
    uri += "?l[]=de&l[]=en" # doesn't fit into params hash
    params = {
      "q" => "Erde",
      "qt" => "exact", # match type
      "t" => "all", # search type
      "c" => "" # collection
    }
    params.each { |key, value|
      uri += "&%s=%s" % [key, value] # XXX: hacky and brittle (e.g. lack of URL-encoding)
    }

    visit uri

    assert page.has_css?("#search_results dt", :count => 1)
  end

  test "RDF search returns matches" do
    uri = search_path(:lang => "de", :format => "rdf")
    uri += "?l[]=de&l[]=en" # doesn't fit into params hash
    params = {
      "q" => "Erde",
      "qt" => "exact", # match type
      "t" => "all", # search type
      "c" => "" # collection
    }
    get uri, params

    assert_response :success
    assert_match /<sdc:result rdf:resource.*#result1"\/>/, @response.body
    assert_no_match /#result2"\/>/, @response.body
  end
end
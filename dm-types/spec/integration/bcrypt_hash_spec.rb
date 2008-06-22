
require 'pathname'
require Pathname(__FILE__).dirname.parent.expand_path + 'spec_helper'

describe DataMapper::Types::BCryptHash do
  before(:each) do
    class User
      include DataMapper::Resource

      property :id, Serial
      property :password, BCryptHash
    end
    User.auto_migrate!
    User.create!(:password => "DataMapper R0cks!")
  end

  it "should save a password to the DB on creation" do
    repository(:default) do
      User.create!(:password => "password1")
    end
    user = User.all
    user[0].password.should == "DataMapper R0cks!"
    user[1].password.should == "password1"
  end

  it "should change the password on attribute update" do
    @user = User.first
    @user.attribute_set(:password, "D@t@Mapper R0cks!")
    @user.save
    @user.password.should_not == "DataMapper R0cks!"
    @user.password.should == "D@t@Mapper R0cks!"
  end


end

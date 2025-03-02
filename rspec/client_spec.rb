require 'rspec'
require 'sinatra/base'
require_relative '../client'

RSpec.describe 'Client' do
  before do
    allow(Faraday).to receive(:get).with(any_args) do |*args, **_kwargs|
      uri = URI.parse(args[0])
      path = uri.path
      value = CGI.parse(uri.query)['value'].first

      result = case path
               when '/a'
                 Digest::MD5.hexdigest(value)
               when '/b'
                 Digest::SHA256.hexdigest(value)
               when '/c'
                 Digest::SHA512.hexdigest(value)
               end

      instance_double(Faraday::Response,
                      status: 200,
                      body: result,
                      headers: {'Content-Type' => 'application/json'})
    end
  end

  it { expect(run).to eq '0bbe9ecf251ef4131dd43e1600742cfb' }
end

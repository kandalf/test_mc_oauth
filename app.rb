require 'cuba'
require 'cuba/render'
require 'json'
require 'net/http'
require 'uri'

Cuba.plugin Cuba::Render

Cuba.use Rack::Session::Cookie, { :key => "test_mc_oauth", :secret => "bd84eb20b7178fd265710987d50045c6" }

CLIENT_ID="4c70a331c5c6e42b9543a0d01448ea0b"
CLIENT_SECRET="d759438db0ce08c25910209c9cd44a507d88fd41ea1475bb7ef13a82292aeac7"


Cuba.define do
  on get, root do
    res.write partial("login.html", :client_id => CLIENT_ID)
  end

  on get, "callback" do
    unless session[:mc_api_access_token]
      auth_code = req.params["code"]
      uri       = URI.parse("http://api.missioncontrol.citrusbyte.com/api/1.0/auth/access/tokens")
      http      = Net::HTTP.new(uri.host, uri.port)
      request   = Net::HTTP::Post.new(uri.request_uri)

      request.basic_auth(CLIENT_ID, CLIENT_SECRET)

      request.set_form_data({
        :grant_type => "authorization_code",
        :redirect_uri => "http://localhost:8000/callback",
        :code => auth_code
      })

      response = http.request(request)

      auth_data = JSON.parse(response.body)

      session[:mc_api_access_token] = auth_data["access_token"]
      session['mc.auth'] = auth_data["extra"]["user"]
    end

    res.redirect "/apis"
  end

  on get, "apis" do
    res.redirect "/" unless session[:mc_api_access_token]

    uri = URI.parse("http://api.missioncontrol.citrusbyte.com/api/1.0/services")

    http      = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Token: #{session[:mc_api_access_token]}"

    response = http.request(request)

    puts response.body
    
    if session["mc.auth"]
      user_name = "#{session["mc.auth"]["first_name"]} #{session["mc.auth"]["last_name"]}"
    else
      user_name = "Unknown user"
    end

    data = JSON.parse(response.body)

    res.write partial("services.html", {:services => data["services"], :user_name => user_name })
  end

  on default do
    res.status = 404
    res.write "Not Found"
  end
end

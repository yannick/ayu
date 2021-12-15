

require 'ayu'
class MyApp < Ayu::App 

	class UserResource < Ayu::Resource
		get do 
			{msg: "hello world from ayu!", params: @params, env: @env }.to_json 
		end
	end

	resource('/users/{user_id}', UserResource)
end

MyApp.new
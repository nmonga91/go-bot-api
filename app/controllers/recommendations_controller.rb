require 'net/http'
require 'uri'
require 'json'

class RecommendationsController < ApplicationController

  def index
    # Check required query params
    activity_name = params[:activity_name]
    start_location = params[:start_location]
    trans_mode = params[:trans_mode]

    if activity_name.nil?
      raise('Missing activity name')
    end

    if start_location.nil?
      raise('Missing start location')
    end

    if trans_mode.nil?
      raise('Missing transportation mode')
    end

    # Retrieve top 5 recommendations based on where people from the specified area went
    start_loc_info = get_location_add(start_location)

    render json: {recareas: get_closest_five(start_loc_info, activity_name)}
  end

  # get address of location. ex: "94101" returns "San Francisco, CA, USA"
  def get_location_add(start_loc_input)
    uri = URI("http://maps.googleapis.com/maps/api/geocode/json?address=#{start_loc_input}&sensor=true")
    res = Net::HTTP.get(uri)
    json_result = JSON.parse(res)['results'].first
    return {:address => json_result['formatted_address'],
            :latitude => json_result['geometry']['location']['lat'],
            :longitude => json_result['geometry']['location']['lng']}
  end

  def get_image_url(latitude,longitude)
    uri = URI("https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=62b32c5d41d73672e2953c91a317de3c&lat=#{latitude}&lon=#{longitude}&radius=5&page=100&format=json&nojsoncallback=1&extras=description,license,date_upload,date_taken,owner_name,icon_server,original_format,last_update,geo,tags,machine_tags,o_dims,views,media,path_alias,url_sq,url_t,url_s,url_q,url_m,url_n,url_z,url_c,url_l,url_o")
    res = Net::HTTP.get(uri)
    value = JSON.parse(res)

    image_response = value['photos']['photo'][0]
    image_url = image_response["url_l"]
  end

  def get_closest_five(location_info, activity_name)
    orig_lat = location_info[:latitude]
    orig_lng = location_info[:longitude]

    activities = {:hiking => 14, :biking => 5, :swimming => 106}

    # https://ridb.recreation.gov/api/v1/recareas?apikey=3D698306D5CF4F04A0D561F52B79AFED&radius=5&latitude=37.7749295&longitude=-122.4194155
    # get all recareas within 5 miles of specified location
    uri = URI("https://ridb.recreation.gov/api/v1/recareas.json?apikey=#{ENV['RIDB_API_KEY']}&radius=5&latitude=#{orig_lat}&longitude=#{orig_lng}&activity=#{activities[activity_name.to_sym]}")

    res = Net::HTTP.get(uri)
    recareas = JSON.parse(res)['RECDATA'].first(5)

    # each recarea = {image="", id=0, name="", distance="", travel_time=""}
    simplified_recreas = []
    recareas.each do |recarea|
      dest_lat = recarea['RecAreaLatitude']
      dest_lng = recarea['RecAreaLongitude']

      # https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=40.6655101,-73.89188969999998&destinations=&key=YOUR_API_KEY
      uri = URI("https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=#{orig_lat},#{orig_lng}&destinations=#{dest_lat},#{dest_lng}&key=#{ENV['GOOGLE_MAPS_API_KEY']}")
      res = Net::HTTP.get(uri)
      map_json_result = JSON.parse(res)

      distance = map_json_result['rows'].first['elements'].first['distance']['text']
      travel_time = map_json_result['rows'].first['elements'].first['duration']['text']

      ra = {:id => recarea['RecAreaID'].to_s, :name => recarea['RecAreaName'].titleize,
            :image => get_image_url(dest_lat, dest_lng), :distance => distance, :travel_time => travel_time,
            :latitude => dest_lat, :longitude => dest_lng}

      simplified_recreas << ra
    end

    return simplified_recreas
  end

end

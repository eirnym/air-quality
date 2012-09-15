require 'exifr'
require 'yaml'

class Potd
  attr_accessor :description, :found_for, :url, :width, :height, :lat, :lon, :created_at, :camera, :copyright


  def to_html
    "<img src=\"#{@url}\" width=\"#{@width}\" height=\"#{@height}\" class=\"img-rounded\" />"
  end


  def find(d, span, preview=false)
    paths = []
    @found_for = d
    case span 
      when :day
        #look today and yesterday
        paths << d.date_path
        paths << Time.at(d.to_i - 24.hours).date_path

      when :month
        #look anywhere in month
        paths << [d.year, "%02d" % d.month].join(File::SEPARATOR)

      when :season
        #look anywhere in season
        season = d.month.between(3,11)? Array(d.month..d.month+2) : [12,1,2]
        season.each do |sm|
          paths << [d.year, "%02d" % sm].join(File::SEPARATOR)
        end

      when :year
        paths << d.year.to_s
    end

    images = []
    re = (preview)? /\d+s\.jpg$/ : /\d+\.jpg$/
    d = [BASE_DIR, 'public', 'potd'].join(File::SEPARATOR)
    paths.each do |p|
      image_dir = [d,p].join(File::SEPARATOR)
      next unless File.exists?(image_dir)
      images += Dir.entries(image_dir).grep(re).map {|i| [p,i]}
    end

    if images.size > 0
      i = images.sample
      load_info(([d] + i).join(File::SEPARATOR))
      @url = ['', 'potd', i[0], i[1]].join('/')
    else
      return nil
    end
  end

  def load_info(f)
    fe = EXIFR::JPEG.new(f)
    @width = fe.width
    @height = fe.height
    @created_at = fe.date_time.our_format
    @camera = fe.model
    @copyright = fe.copyright
    if !fe.gps_latitude_ref.nil?
      ll = dms2dec(fe.gps_latitude_ref, fe.gps_latitude, fe.gps_longitude_ref, fe.gps_longitude )
      @lat = ll[0]
      @lon = ll[1]
    end
    # load values from description file if it exists
    d_file = [File.dirname(f), File.basename(f, '.jpg').gsub(/\D/, '') + '.yml'].join(File::SEPARATOR)
    if File.exists?(d_file)
      begin
        img_data = YAML::load_file(d_file)
        @description = img_data['description']
        @lat = img_data['gps']['lat'] unless img_data['gps']['lat'].nil?
        @lon = img_data['gps']['lon'] unless img_data['gps']['lon'].nil?
      rescue Exception => e
        # error loading yml file.
        @description = 'invalid yml description file'
      end
    end
  end

  private 
    # gps coordinates as returned by exifr
    def dms2dec(lat_ref, alat, lon_ref, alon)
      sign_lat = lat_ref.upcase.eql?('N')? 1 : -1
      sign_lon = lon_ref.upcase.eql?('E')? 1 : -1
      return [
        sign_lat*((alat[0]*3600 + alat[1]*60 + alat[2])/3600).to_f,
        sign_lon*((alon[0]*3600 + alon[1]*60 + alon[2])/3600).to_f
      ]
    end


end

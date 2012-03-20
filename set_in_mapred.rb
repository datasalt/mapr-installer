require 'rubygems'
require 'xmlsimple'


input_file=ARGV[0]
output_file=ARGV[1]
expected_property=ARGV[2]
supplied_value=ARGV[3]

puts "Input file: #{input_file}"
puts "Output file: #{output_file}"
puts "Setting Property: #{expected_property} => #{supplied_value}"

#data = XmlSimple.xml_in(input_file,"ForceArray"=>false)
data = XmlSimple.xml_in(input_file)

found=false

#puts "Num properties in mapred-site.xml : #{data['property'].length}"
data['property'].each do |property|
    if property["name"][0] == expected_property then
        property['value'][0] = supplied_value
        found=true
    end
end

if not found then
  #puts "Property #{expected_property} was not found. Setting it"
  #new_data=Hash["name"=>expected_property, "value"=>supplied_value]
  new_data = Hash.new
  new_data['name'] = [expected_property]
  new_data['value'] = [supplied_value]
  data['property'] << new_data
  #puts "Data property has length : #{data['property'].length}" 
  #data['property'].add {"name"=> expected_property, "value"=> supplied_value}
end

XmlSimple.xml_out(data,"OutputFile" => output_file,"RootName"=>"configuration")


#doc = REXML::Document.new XmlSimple.xml_out(data, 'AttrPrefix' => true)
#doc.write
#out = XmlSimple.xml_out("out.xml")
#out.write data






# ARGV[0] - port
# ARGV[1] - input1 path prefix
# ARGV[2] - input2 path prefix
# ARGV[3] - entry script file
# ARGV[4] - input sample file

require 'fileutils'

FileUtils.rm Dir.glob('output*')
FileUtils.rm Dir.glob('Output*')

script = ARGV[3]
server_id = Process.spawn("node #{script}")
sleep 1

def get_output1(input1, input2)
  output1 = []
  index = 0
  while index < input1.length do
    output1 << input1[index]
    index += 1
    break unless index < input2.length
    output1 << input2[index]
    index += 1    
  end
  output1
end

def get_output2(input1, input2)
  output2 = []
  index = 0
  while index < input2.length do
    output2 << input2[index]
    break unless index < input1.length
    
    output2 << input1[index]
    index += 1
  end
  output2
end


text=File.open(ARGV[4]).read


line_num=0
input1 = []
input2 = []

# support windows EOL
text.gsub!(/\r\n?/, "\n")

port = ARGV[0]
hostname = 'http://localhost:' + port

input1_url = hostname + ARGV[1] + '/'
input2_url = hostname + ARGV[2] + '/'


state = :input 

text.each_line do |raw_line|
  puts "#{line_num += 1} #{raw_line}"

  line = raw_line.strip
  break if line == '----'
  parts = line.split(' ')
  if (parts[0].to_i == 1)
    input1 << parts[1]
    cmd = "curl #{input1_url}#{parts[1]}"
    puts "Running #{cmd}"
    system(cmd)
  elsif (parts[0].to_i == 2)
    input2 << parts[1]
    cmd = "curl #{input2_url}#{parts[1]}"
    puts "Running #{cmd}"
    system(cmd)
  else
    throw "Error reading #{line_num}"
  end
end

output1 = get_output1(input1, input2)
output2 = get_output2(input1, input2)

def uncapitalize(name)
  name[0, 1].downcase + name[1..-1]
end

def get_file_name(name)
  candidates = [
    uncapitalize(name),
    uncapitalize(name) + '.txt',
    name.capitalize,
    name.capitalize + '.txt'
  ]
  candidates.each do |file|
    return file if File.file?(file)
  end
end

def read_output(file)
  file_name = get_file_name file
  puts file_name
  content = File.read(file_name)
  delimiter = content.split(',').length > 1 ? ',' : "\n"
  return content.split(delimiter).map { |x| x.strip }
end


actual_output1 = read_output('output1')

actual_output2 = read_output('output2')

puts "output1:"
puts "actual:   #{actual_output1}"
puts "expected: #{output1} "

puts "output2:"
puts "actual:   #{actual_output2}"
puts "expected: #{output2}"

puts server_id
Process.kill('HUP', server_id)

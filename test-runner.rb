# ARGV[0] - input sample file

# To run the tests:
# 1. have the candidate's code submission files at
# <root>/<candidate-name>/<code-folder>
# 2. have the evaluation folder at
# <root>/evaluation
# 3. cd into candidate's code folder
# 4. Create a runner-config.json file in the folder with the details of port, output file names, 
#  input urls and command to run. See default_runner_config below for sample config.
# 5. Run the following command:
# ruby ../../evaluation/test-runner.rb ../../evaluation/sample.txt
# It starts the server of the candidate's code, runs test case and kills the server.



require 'fileutils'
require 'json'

default_runner_config = {
  port: 3000,
  output1: 'output1.txt',
  output2: 'output2.txt',
  input1_url: '/input1',
  input2_url: '/input2',
  command: 'npm start',
}

# ```
# Sample:
# {
#   "port": 3000,
#   "output1": "output1.txt",
#   "output2": "output2.txt",
#   "input1_url": "/input1",
#   "input2_url": "/input2",
#   "command": "npm start"
# }
# ```


begin
  config = JSON.parse(File.read 'runner-config.json')
  config = Hash[config.map{ |k, v| [k.to_sym, v] }]
  config = default_runner_config.merge config
rescue Exception => err
  puts err
  raise err
end

sample_file = ARGV[0]
port = config[:port].to_s

config[:delete_output_files] = config[:delete_output_files].nil?  ? true : config[:delete_output_files]

if config[:delete_output_files]
  File.delete config[:output1] if File.exist? config[:output1]
  File.delete config[:output2] if File.exist? config[:output2]
end

server_id = Process.spawn(config[:command])
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

begin
  text=File.open(sample_file).read

  line_num = 0
  input1 = []
  input2 = []

  # support windows EOL
  text.gsub!(/\r\n?/, "\n")

  hostname = 'http://localhost:' + port

  input1_url = hostname + config[:input1_url] + '/'
  input2_url = hostname + config[:input2_url] + '/'

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
      name.capitalize + '.txt',
    ]
    candidates.each do |file|
      return file if File.file?(file)
    end
  end

  def read_output(file_name)
    puts "Reading #{file_name}"
    content = File.read(file_name)
    delimiter = content.split(',').length > 1 ? ',' : "\n"
    return content.split(delimiter).map { |x| x.strip }
  end


  actual_output1 = read_output(config[:output1] || (get_file_name 'output1'))

  actual_output2 = read_output(config[:output2] || (get_file_name 'output2'))

  puts "output1:"
  puts "actual:   #{actual_output1}"
  puts "expected: #{output1} "

  puts "output2:"
  puts "actual:   #{actual_output2}"
  puts "expected: #{output2}"

rescue Exception => err
  puts err
ensure
  puts "killing server process:#{server_id}"
  Process.kill('HUP', server_id)
end

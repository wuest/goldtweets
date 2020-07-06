Gem::Specification.new do |s|
  s.name = 'goldtweets'
  s.version = '0.0.1'

  s.description = 'Ruby port of the Python GetOldTweets3 Twitter library'
  s.summary     = 'Search Twitter including older tweets'
  s.authors     = ['Tina Wuest']
  s.email       = 'tina@wuest.me'
  s.homepage    = 'https://gitlab.com/wuest/goldtweets'
  s.license     = 'MIT'
  s.files       = `git ls-files lib`.split("\n")

  s.required_ruby_version = '>= 2.5.0'

  s.add_dependency('nokogiri', '~> 1.10')

  s.add_development_dependency('rake', '~> 13')
  s.add_development_dependency('minitest', '~> 5')
end

require 'goldtweets/client'
require 'goldtweets/search'
require 'goldtweets/tweet'

module GoldTweets
  # Convenience method, identical to calling GoldTweets::Client.get_tweets
  def self.get_tweets(criteria)
    ::GoldTweets::Client.get_tweets(criteria)
  end
end

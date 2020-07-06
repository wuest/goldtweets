module GoldTweets
  # Reflects interesting data returned by the API
  Tweet = Struct.new(:username, :text, :retweets, :faves, :replies, :hashtags, :mentions, :to, :id, :permalink, :author_id, :timestamp, :geo, :links)
end

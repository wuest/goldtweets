module GoldTweets
  Search = Struct.new(:username,
                      :exclude_words,
                      :since,
                      :upto,
                      :minimum_replies,
                      :minimum_faves,
                      :minimum_retweets,
                      :maximum_distance,
                      :near,
                      :lat,
                      :lon,
                      :query,
                      :maximum_tweets,
                      :language,
                      :emoji,
                      :top_tweets,
                      keyword_init: true) do

    # Set default values, otherwise no additional work done here.
    def initialize(username: nil,
                   exclude_words: [],
                   since: nil,
                   upto: nil,
                   minimum_replies: nil,
                   minimum_faves: nil,
                   minimum_retweets: nil,
                   maximum_distance: '15mi',
                   near: nil,
                   lat: nil,
                   lon: nil,
                   query: nil,
                   maximum_tweets: 0,
                   language: '',
                   emoji: :ignore,
                   top_tweets: false)
      username = username
      exclude_words = exclude_words
      since = since
      upto = upto
      minimum_replies = minimum_replies
      minimum_retweets = minimum_retweets
      maximum_distance = maximum_distance
      query = query
      maximum_tweets = maximum_tweets
      language = language
      emoji = emoji
      top_tweets = top_tweets
      super
    end

    alias_method :usernames=, :username=
    alias_method :usernames, :username
    alias_method :top_tweets?, :top_tweets
  end
end

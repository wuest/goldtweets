## GoldTweets - GetOldTweets3, Ruby-style

A re-implementation of [GetOldTweets3][main0]'s API in Ruby, allowing for
accessing of old tweets.  The command line utility provided by the original work
is excellent and not presently reimplemented.

### Example Usage

#### Search for tweets by user(s):

```ruby
criteria = GoldTweets::Search.new
criteria.username = 'twitter'
criteria.maximum_tweets = 20 # minimum returned by Twitter's search
tweets = GoldTweets.get_tweets(criteria)
puts tweets.first.text
```

#### Search for tweets with a particular query:

```ruby
criteria = GoldTweets::Search.new
criteria.maximum_tweets = 20 # minimum returned by Twitter's search
criteria.query = 'ruby monad'
tweets = GoldTweets.get_tweets(criteria)
puts tweets.first.text
```

### Limitations

The implementation is as yet incomplete, lacking some features (emoji handling,
passing a custom block to perform additional processing on tweets before they're
returned, proxy support, &c.)

[main0]:https://github.com/Mottl/GetOldTweets3

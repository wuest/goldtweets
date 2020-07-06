require 'test_helper'

class SearchTest < Minitest::Test
  def new_search
    criteria = GoldTweets::Search.new
    criteria.usernames = ['twitter', 'twittercomms']
    criteria.maximum_tweets = 1
    criteria
  end

  def test_single_username_search
    criteria = new_search
    criteria.username = 'twitter'
    tweets = GoldTweets.get_tweets(criteria)

    refute_empty(tweets)
    assert_equal('Twitter', tweets.first.username)
    assert_equal(['Twitter'], tweets.map(&:username).uniq)
    refute_empty(tweets.first.text)
  end

  def test_multiple_username_search
    criteria = new_search
    criteria.maximum_tweets = 40
    tweets = GoldTweets.get_tweets(criteria)

    refute_empty(tweets)
    assert_equal(['Twitter', 'TwitterComms'], tweets.map(&:username).uniq.sort)
    refute_empty(tweets.first.text)
  end

  def test_zero_username_search
    criteria = GoldTweets::Search.new
    criteria.maximum_tweets = 1
    criteria.query = 'rubylang'
    tweets = GoldTweets.get_tweets(criteria)

    refute_empty(tweets)
    refute_empty(tweets.first.text)
  end

  def test_query_search
    criteria = new_search
    criteria.query = '#AskTheAG #COVID19'
    tweets = GoldTweets.get_tweets(criteria)

    assert_equal(['#AskTheAG', '#COVID19'], tweets.first.hashtags.sort)
  end
end

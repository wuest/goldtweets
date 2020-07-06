# frozen_string_literal: true

require 'json'
require 'nokogiri'
require 'net/http'
require 'uri'

require 'goldtweets/tweet'

module GoldTweets
  module Client
    # User agents to present to Twitter search
    USER_AGENTS = [ 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:63.0) Gecko/20100101 Firefox/63.0',
                    'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:62.0) Gecko/20100101 Firefox/62.0',
                    'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:61.0) Gecko/20100101 Firefox/61.0',
                    'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0',
                    'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36',
                    'Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36',
                    'Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko',
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15'
                  ].freeze

    # Static list of headers to be sent with API requests
    DEFAULT_HEADERS = { 'Host' => 'twitter.com',
                        'Accept' => 'application/json, text/javascript, */*; q=0.01',
                        'Accept-Language' => 'en-US,en;q=0.5',
                        'X-Requested-With' => 'XMLHttpRequest',
                        'Connection' => 'keep-alive'
                      }.freeze
    # How many usernames to put in a single search
    USERNAMES_PER_BATCH = 20

    # URLs for searching and generating permalinks back to tweets
    SEARCH_PREFIX = 'https://twitter.com/i/search/timeline?'
    PERMALINK_PREFIX = 'https://twitter.com'

    # Static list of parameters sent with a search
    DEFAULT_PARAMETERS = { 'vertical' => 'news',
                           'src' => 'typd',
                           'include_available_features' => '1',
                           'include_entities' => '1',
                           'reset_error_state' => 'false'
                         }.freeze

    # XPath selectors
    TWEETS_SELECTOR    = "//div[contains(concat(' ', normalize-space(@class), ' '), ' js-stream-tweet ') and not(contains(concat(' ', normalize-space(@class), ' '), ' withheld-tweet '))]"
    USERNAMES_SELECTOR = ".//span[contains(concat(' ', normalize-space(@class), ' '), ' username ') and contains(concat(' ', normalize-space(@class), ' '), ' u-dir ')]/b"
    AUTHORID_SELECTOR  = ".//a[contains(concat(' ', normalize-space(@class), ' '), ' js-user-profile-link ')]"
    CONTENT_SELECTOR   = ".//p[contains(concat(' ', normalize-space(@class), ' '), ' js-tweet-text ')]"
    RETWEETS_SELECTOR  = ".//span[contains(concat(' ', normalize-space(@class), ' '), ' ProfileTweet-action--retweet ')]/span[contains(concat(' ', normalize-space(@class), ' '), ' ProfileTweet-actionCount ')]"
    FAVORITES_SELECTOR = ".//span[contains(concat(' ', normalize-space(@class), ' '), ' ProfileTweet-action--favorite ')]/span[contains(concat(' ', normalize-space(@class), ' '), ' ProfileTweet-actionCount ')]"
    REPLIES_SELECTOR   = ".//span[contains(concat(' ', normalize-space(@class), ' '), ' ProfileTweet-action--reply ')]/span[contains(concat(' ', normalize-space(@class), ' '), ' ProfileTweet-actionCount ')]"
    TIMESTAMP_SELECTOR = ".//small[contains(concat(' ', normalize-space(@class), ' '), ' time ')]//span[contains(concat(' ', normalize-space(@class), ' '), ' js-short-timestamp ')]"
    GEO_SELECTOR       = ".//span[contains(concat(' ', normalize-space(@class), ' '), ' Tweet-geo ')]"
    LINK_SELECTOR      = ".//a"

    # Interim response structure useful for tweet fetch and processing logic
    Response = Struct.new(:body, :new_cursor, :new_cookies, :more_items)

    # Fetch tweets based on a GoldTweets::Search object
    # This functionality is presently lacking several features of the original
    # python library - proxy support, emoji handling, and allowing a provided
    # block to be run on tweets as they are processed among them.
    def self.get_tweets(criteria)
      user_agent = USER_AGENTS.sample
      cookie_jar = ''
      usernames  = usernames_for(criteria.usernames)
      batches    = usernames.each_slice(USERNAMES_PER_BATCH).to_a

      batches.map do |batch|
        refresh_cursor      = ''
        batch_results_count = 0
        collected_tweets    = []

        criteria.usernames = batch
        loop do
          response       = fetch_tweets(criteria, refresh_cursor, cookie_jar, user_agent)
          cookie_jar     = response.new_cookies if response.new_cookies
          refresh_cursor = response.new_cursor

          tweets   = response.body.xpath(TWEETS_SELECTOR).reduce([], &method(:parse_tweet))
          collected_tweets << tweets
          batch_results_count += tweets.length

          if (criteria.maximum_tweets.to_i > 0 && batch_results_count >= criteria.maximum_tweets) || (!response.more_items)
            break
          end
        end

        collected_tweets.flatten
      end.flatten
    end

    private

    # Coerce usernames into a suitable representation for batching
    def self.usernames_for(users)
      case users
      when Array
        users.map { |u| u.sub(/^@/, '').downcase }
      when String
        [ users.sub(/^@/, '').downcase ]
      else
        [[]]
      end
    end

    # Function for folding a list of Nokogiri objects fetched from Twitter into
    # a list of GoldTweets::Tweet objects
    def self.parse_tweet(tweets, tweet)
      users    = tweet.xpath(USERNAMES_SELECTOR).map(&:text)
      return tweets if users.empty?

      message   = tweet.xpath(CONTENT_SELECTOR).map(&method(:sanitize_message)).first
      rt,f,re   = tweet_interactions(tweet)
      permalink = PERMALINK_PREFIX + tweet.attr('data-permalink-path')
      author    = tweet.xpath(AUTHORID_SELECTOR).map { |t| t.attr('data-user-id').to_i }.first
      timestamp = tweet.xpath(TIMESTAMP_SELECTOR).map { |t| Time.at(t.attr('data-time').to_i) }.first
      links     = tweet.xpath(LINK_SELECTOR)
      hts, ats  = tweet_hashtags_and_mentions(links)
      geo_span  = tweet.xpath(GEO_SELECTOR).map { |t| t.attr('title') }.first.to_s
      ext_links = links.map { |t| t.attr('data-expanded-url') }.select(&:itself)

      tweet_container           = ::GoldTweets::Tweet.new(users.first)
      tweet_container.to        = users[1]
      tweet_container.text      = message
      tweet_container.retweets  = rt
      tweet_container.faves     = f
      tweet_container.replies   = re
      tweet_container.id        = tweet.attr('data-tweet-id')
      tweet_container.permalink = permalink
      tweet_container.author_id = author
      tweet_container.timestamp = timestamp
      tweet_container.hashtags  = hts
      tweet_container.mentions  = ats
      tweet_container.geo       = geo_span
      tweet_container.links     = ext_links

      tweets + [tweet_container]
    end

    # Normalize spacing and remove errant spaces following pound signs, at
    # signs, and dollar signs
    def self.sanitize_message(tweet)
      tweet.text
           .gsub(/\s+/, ' ')
           .gsub(/([#@\$]) /, '\1')
    end

    # Classify interactions (retweets, faves, and replies to a given tweet)
    def self.tweet_interactions(tweet)
      [RETWEETS_SELECTOR, FAVORITES_SELECTOR, REPLIES_SELECTOR].map do |selector|
        tweet.xpath(selector)
             .map { |node| node.attr('data-tweet-stat-count') }
             .first
             .to_i
      end
    end

    # Classify links belonging to hashtags and (outgoing) mentions within a
    # tweet
    def self.tweet_hashtags_and_mentions(links)
      links.reduce([[], []]) do |(hashtags, mentions), link|
        href = link.attr('href')
        return [hashtags, mentions] unless href.to_s[0] == '/'
        if link.attr('data-mentioned-user-id')
          [hashtags, mentions + ['@' + href[1..-1]]]
        elsif /^\/hashtag\//.match(href)
          [hashtags + [href.sub(/(?:^\/hashtag\/)/, '#').sub(/(?:\?.*$)/, '')], mentions]
        else
          [hashtags, mentions]
        end
      end
    end

    # Perform a search for tweets based on criteria specified
    def self.fetch_tweets(criteria, refresh_cursor, cookie_jar, user_agent)
      search   = DEFAULT_PARAMETERS.dup
      get_data = []
      search['f'] = 'tweets' unless criteria.top_tweets?
      search['l'] = criteria.language if criteria.language

      get_data << criteria.query if criteria.query
      get_data << ([''] + criteria.exclude_words).join(' -')
      get_data << criteria.username.map { |u| "from:#{u}" }.join(' OR ') if criteria.username
      get_data << "since:#{criteria.since}" if criteria.since
      get_data << "until:#{criteria.upto}" if criteria.upto
      get_data << "min_replies:#{criteria.minimum_replies}" if criteria.minimum_replies
      get_data << "min_faves:#{criteria.minimum_faves}" if criteria.minimum_faves
      get_data << "min_retweets:#{criteria.minimum_retweets}" if criteria.minimum_retweets

      if criteria.maximum_distance
        if criteria.near
          get_data << "near:#{criteria.near} within:#{criteria.maximum_distance}"
        elsif criteria.lat && criteria.lon
          get_data << "geocode:#{criteria.lat},#{criteria.lon},#{criteria.maximum_distance}"
        end
      end

      search['q'] = get_data.join(' ').strip
      search['max_position'] = refresh_cursor

      url = SEARCH_PREFIX + URI.encode_www_form(search)
      uri = URI(url)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        DEFAULT_HEADERS.each { |(k,v)| request[k] = v }
        request['User-Agent'] = user_agent
        request['Referer'] = url
        request['Set-Cookie'] = cookie_jar

        response = http.request(request)

        json        = JSON.parse(response.body)
        html        = Nokogiri::HTML(json['items_html'])
        new_cursor  = json['min_position']
        new_cookies = response['set-cookie']
        unfinished  = json['has_more_items']

        return Response.new(html, new_cursor, new_cookies, unfinished)
      end
    end
  end
end

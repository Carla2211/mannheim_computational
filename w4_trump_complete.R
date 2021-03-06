require(tidyverse)
require(quanteda)
require(rio)
require(lubridate)

trump_tweets <- import('./data/trump.json') %>% as_tibble

### preprocessing

trump_tweets %>% mutate(is_retweet = is_retweet == "true", created_at = parse_date_time(created_at, orders = '%a %b %d %H:%M:%S %z %Y')) -> trump_tweets

trump_tweets %>% group_by(source) %>% count

trump_tweets %>% filter(str_detect(source, "iPhone|Android")) -> trump_tweets

### quanteda

trump_corpus <- corpus(trump_tweets$text)
docvars(trump_corpus, "source") <- trump_tweets$source
docvars(trump_corpus, "created_at") <- trump_tweets$created_at

## YOUR TURN: add one more docvars - retweet_count
docvars(trump_corpus, "retweet_count") <- trump_tweets$retweet_count

summary(trump_corpus)

## KWIC keyword in context

kwic(trump_corpus, "bush")

kwic(trump_corpus, "cruz")

## YOUR TURN: kwic hillary

kwic(trump_corpus, "hillary")


## Corpus -> dfm

trump_dfm <- dfm(trump_corpus)

topfeatures(trump_dfm, 100) ## WTF

?dfm
?tokens

trump_dfm <- dfm(trump_corpus, remove_punct = TRUE, remove_url = TRUE, remove_numbers = TRUE, remove_symbols = TRUE)
topfeatures(trump_dfm, 100)

stopwords("en")

trump_dfm <- dfm(trump_corpus, remove_punct = TRUE, remove_url = TRUE, remove_numbers = TRUE, remove_symbols = TRUE, remove = stopwords('en'))

topfeatures(trump_dfm, 100)

textplot_wordcloud(trump_dfm, min_count = 300, random_order = FALSE)

## FYI: explore remove_twitter

## keyness

textstat_keyness(trump_dfm, str_detect(docvars(trump_dfm, "source"), "Android"), sort = TRUE) %>% head(n = 100)

textstat_keyness(trump_dfm, str_detect(docvars(trump_dfm, "source"), "Android"), sort = TRUE) %>% textplot_keyness

## Dictionary-based method: introduction

kwic(trump_corpus, "me")

### because stopwords include pronouns...

trump_dfm2 <- dfm(trump_corpus, remove_punct = TRUE, remove_url = TRUE, remove_numbers = TRUE, remove_symbols = TRUE)


pronouns <- dictionary(list(
    first_singular = c("i", "me", "my", "mine", "myself"),
    second = c("you", "your", "yours", "yourself", "yourselves"),
    first_plural = c('we', 'us', 'our', 'ours', 'ourselves'),
    third_masculine = c('he', 'him', 'his', 'himself'),
    third_feminine = c('she', 'her', 'hers', 'herself'),
    other = c('it', 'its', 'itself', 'they', 'them', 'their', 'themselves', 'themself')
))

trump_pronouns <- dfm_lookup(trump_dfm2, dictionary = pronouns)

trump_corpus[1]
trump_pronouns[1,]

textstat_keyness(trump_pronouns, str_detect(docvars(trump_pronouns, "source"), "Android"), sort = TRUE)

## Your Turn: Create a dictionary of
## 1. populism (Rooduijn & Pauwels 2011) with these words:
## c('elit*', 'consensus*', 'undemocratic*', 'referend*', 'corrupt*', 'propagand*', 'politici*', '*deceit*', '*deceiv*', '*betray*', 'shame*', 'scandal*', 'truth*', 'dishonest*', 'establishm*', 'ruling*')
## 2. Terrorism
## c('terror*')
## 3. Tax
## c('tax*')
## And study the difference of these words in Trump's tweets from Android and iPhone

our_dictionary <- dictionary(list(
  populism = c('elit*', 'consensus*', 'undemocratic*', 'referend*', 'corrupt*', 'propagand*', 'politici*', '*deceit*', '*deceiv*', '*betray*', 'shame*', 'scandal*', 'truth*', 'dishonest*', 'establishm*', 'ruling*'),
  terrorism = c("terror*"),
  tax = c("tax*")
))

trump_our_dictionary <- dfm_lookup(trump_dfm2, dictionary = our_dictionary)
textstat_keyness(trump_our_dictionary, str_detect(docvars(trump_our_dictionary, "source"), "Android"), sort = TRUE)


## off-the-shelf dictionary
## validate

afinn <- readRDS('./data/afinn.RDS')

## STEP 1: randomly select some tweets
## trump_tweets %>% sample_n(50) %>% select(text) %>% saveRDS('./data/validation.RDS')
## readRDS('./data/validation.RDS') %>% mutate(tid = seq_along(text)) %>% rio::export('./data/validation.csv')
## STEP 2: read those tweets. Assess the sentiment

## STEP 3: study the correlation between human-coding and machine judgements (e.g. the sentiment score)
validation <- readRDS('./data/validation.RDS')
answer <- import("https://docs.google.com/spreadsheets/d/1tqwEXCgIHFQOGknh_MJKxQQy9nCs8NTCNmCjorJHVUI/edit#gid=1459294491")

gold_standard <- answer$avg[1:20]

corpus(validation$text) %>% dfm %>% dfm_lookup(dictionary = afinn) -> val_dfm

val_dfm %>% quanteda::convert(to = 'data.frame') %>%
  mutate(afinn_score = (neg5 * -5) + (neg4 * -4) + (neg3 * -3) + (neg2 * -2) +
           (neg1 * -1) + (zero * 0) + (pos1 * 1) + (pos2 * 2) + (pos3 * 3) +
           (pos4 * 4) + (pos5 * 5)) %>% select(afinn_score) -> afinn_score
plot(gold_standard, afinn_score$afinn_score[1:20])
### If the sentiment dictionary is reasonably good, use it for analysis.

trump_afinn <- dfm_lookup(trump_dfm2, dictionary = afinn)

quanteda::convert(trump_afinn, to = 'data.frame') %>%
    mutate(afinn_score = (neg5 * -5) + (neg4 * -4) + (neg3 * -3) + (neg2 * -2) +
               (neg1 * -1) + (zero * 0) + (pos1 * 1) + (pos2 * 2) + (pos3 * 3) +
               (pos4 * 4) + (pos5 * 5)) %>% select(afinn_score) %>%
        mutate(android = str_detect(docvars(trump_afinn, "source"), "Android")) -> afinn_score

afinn_score %>% group_by(android) %>% summarize(mean_afinn_score = mean(afinn_score), sd_afinn_score = sd(afinn_score))

cor(afinn_score$afinn_score, trump_tweets$retweet_count, method = 'spearman')


### Out of Syllabus
##require(ggridges)
##afinn_score %>% ggplot(aes(x = afinn_score, y = android)) + geom_density_ridges()


## References:
## Rooduijn, M., & Pauwels, T. (2011). Measuring populism: Comparing two methods of content analysis. West European Politics, 34(6), 1272-1283.
## Hansen, L. K., Arvidsson, A., Nielsen, F. Å., Colleoni, E., & Etter, M. (2011). Good friends, bad news-affect and virality in twitter. In Future information technology (pp. 34-43). Springer, Berlin, Heidelberg.


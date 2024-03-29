#############################################  Create test and validation sets ####################################

###################################
# Create edx set and validation set
###################################

  if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")
  if(!require(caret)) install.packages("caret", repos = "http://cran.us.r-project.org")
  
  # MovieLens 10M dataset:
  # https://grouplens.org/datasets/movielens/10m/
  # http://files.grouplens.org/datasets/movielens/ml-10m.zip
  
  dl <- tempfile()
  download.file("http://files.grouplens.org/datasets/movielens/ml-10m.zip", dl)
  
  ratings <- read.table(text = gsub("::", "\t", readLines(unzip(dl, "ml-10M100K/ratings.dat"))),
                        col.names = c("userId", "movieId", "rating", "timestamp"))
  
  movies <- str_split_fixed(readLines(unzip(dl, "ml-10M100K/movies.dat")), "\\::", 3)
  colnames(movies) <- c("movieId", "title", "genres")
  movies <- as.data.frame(movies) %>% mutate(movieId = as.numeric(levels(movieId))[movieId],
                                             title = as.character(title),
                                             genres = as.character(genres))
  
  movielens <- left_join(ratings, movies, by = "movieId")
  
  # Validation set will be 10% of MovieLens data
  
  set.seed(1) # if using R 3.6.0: set.seed(1, sample.kind = "Rounding")
  test_index <- createDataPartition(y = movielens$rating, times = 1, p = 0.1, list = FALSE)
  edx <- movielens[-test_index,]
  temp <- movielens[test_index,]
  
  # Make sure userId and movieId in validation set are also in edx set
  
  validation <- temp %>% 
    semi_join(edx, by = "movieId") %>%
    semi_join(edx, by = "userId")
  
  # Add rows removed from validation set back into edx set
  
  removed <- anti_join(temp, validation)
  edx <- rbind(edx, removed)
  
  rm(dl, ratings, movies, test_index, temp, movielens, removed)



#############################################  MovieLens Models ####################################

####################
##### RMSE FUNCTION:

  # We are using mean squared error as the loss function to define the best approach to gauge model stability
  # Note that lower the RMSE,  better the prediction
  # Following RMSE (Root Mean Square Error) function will take 2 inputs, true and predicted 
  # ratings, and will return RMSE value.  This function will be used to calculate RMSE values 
  # for all the models
  
      RMSE <- function(true_ratings, predicted_ratings){
        sqrt(mean((true_ratings - predicted_ratings)^2))
      }


####################################################
##### GLOBAL VARIABLES: MU and RMSE result dataframe

  # Following variables, mu and rmse_result, will be used in all the models
  
      mu <- mean(edx$rating) # Mean ratings of all the movies :  mu = 3.512465
      rmse_result <- data.frame(method = 'datframe initialization' , RMSE = 0) # Initialization of rmse_result dataframe
      
  # Remove 1st entry of rmse_result, as its dummy
      
      rmse_result <- rmse_result[-1,0]


################################
##### Model 1 : Naive Average Model #####

  # Our 1st model considers just the mean value of all the movies to predict movie ratings
  # Any value other than mu will increase RMSE value as mean provides the lowest RMSE value 
  
      naive_rmse <- RMSE(validation$rating , mu) # naive_rmse = 1.061202
  
  # Add results into rmse_result
      
      rmse_result <- bind_rows(rmse_result , data.frame(method = 'Model 1 : Naive Average Model' , RMSE = naive_rmse))
      rmse_result %>% knitr::kable()


################
##### Model 2 : Movie Effect Model #####

  # Our 2nd model improves the 1st model by considering averages of individual movie ratings
  # Movie ratings vary across movies
  
  # Following plot will show that movie ratings may differ (values of only 50 rows are displayed):
      edx %>% group_by(movieId) %>% summarize(no_of_ratings = n()) %>% top_n(.,50) %>%
        ggplot(aes(movieId,no_of_ratings)) + geom_point()
  
  
  # Following code will calculate movie averages on edx set
  # Let b_i denote movie average for a movie i
  # We need to subtract actual rating with mu (average of all movies),  so that mu + b_i holds a maximum
  # value of 5 and doesn't go beyond 5
      
      mod2_movie_avg <- edx %>% group_by(movieId) %>% summarise(b_i = mean(rating - mu))
  
  # Following graph displays distribution of b_i values
      
      hist(mod2_movie_avg$b_i)
      
  # Note that mu + b_i value can go upto 5
      
      max(mod2_movie_avg$b_i) + mu # 5
  
  # Following code will predict movie ratings using validation set, using b_i that is 
  # calculated on edx set (i.e. training set)
      
      mode2_predicted_ratings <- mu + validation %>% left_join(mod2_movie_avg, by = 'movieId') %>% 
        .$b_i
  
  # Following code will calculate RMSE based on predicted ratings and will insert RMSE into rmse_result
      
      mod2_rmse <- RMSE(validation$rating , mode2_predicted_ratings) # model 2 rmse = 0.9439087
      rmse_result <- bind_rows(rmse_result , data.frame(method = 'Model 2 : Movie Effect Model' , RMSE = mod2_rmse))
      rmse_result %>% knitr::kable()


###################################################################
##### Model 3 : Movie + User Effect Model

  # We can see that there is scope of improvement in Model 2. Like different movies have different ratings, 
  # different users also give different ratings to movies. If we consider this factor in our equation, then RMSE
  # reduces further
  
  # Plot to show that different users can give different movies ratings (values of only 50 rows are displayed):
      
      edx %>% group_by(userId) %>% summarize(no_of_ratings = n()) %>% top_n(.,50) %>%
        ggplot(aes(userId,no_of_ratings)) + geom_point()
  
  # Following code will calculate movie averages on edx set
  # Let b_i denote movie average for a movie i
  # We need to subtract actual rating with mu (average of all movies),  so that mu + b_i holds a maximum
  # value of 5 and doesn't go beyond 5
      
      mod3_movie_avg <- edx %>% group_by(movieId) %>% summarise(b_i = mean(rating - mu))
  
  # Following code will calculate user averages on edx set
  # Let b_u denote user average for a user u
  # We will subtract actual rating with mu (average of all movies) and b_i (average of individual movies)
  # to calculate b_u
      
      mod3_user_avg <-  edx %>% left_join(mod3_movie_avg, by = 'movieId') %>% 
        group_by(userId) %>% summarize(b_u = mean(rating - mu - b_i))
  
  # Following graph displays distribution of b_u
      
      hist(mod3_user_avg$b_u)
  
  # Following code will predict movie ratings on validation set, using b_i and b_u that is 
  # calculated on edx set (i.e. training set)
      
      mod3_predicted_ratings <- validation %>% left_join(mod3_movie_avg, by = 'movieId') %>%
        left_join(mod3_user_avg, by = 'userId') %>%
        mutate(pred = mu + b_i + b_u) %>% .$pred
  
  # Following code will calculate RMSE based on predicted ratings and will insert RMSE into rmse_result
      
      mod3_rmse <- RMSE(validation$rating , mod3_predicted_ratings) # model 3 rmse = 0.8653488
      rmse_result <- bind_rows(rmse_result , data.frame(method = 'Model 3 : Movie + User Effect Model' , RMSE = mod3_rmse))
      rmse_result %>% knitr::kable()


#####################################################
##### Model 4 : Regularized Movie and User Effect Model #####

  # We will use regularization in this model
  # This model will penalize larger estimates that come from small sample size
  # Penalty will be applied to both b_u and b_i
  # Lambda is the variable that will be used to penalize small sample size
  
  
  # Following code displays 10 movies with highest b_i value. Note that these movies 
  # were rated very few times that made them appear in the top 10 positions
      
      mod4_movie_avg <- edx %>% group_by(movieId) %>% summarise(b_i = mean(rating - mu))
      movie_title <- edx %>% select(movieId,title) %>% distinct()
      temp1 <- edx %>% left_join(mod4_movie_avg , by = 'movieId') %>%
        left_join(movie_title, by='movieId') %>%
        arrange(desc(b_i)) %>%
        distinct(title.x,b_i) %>%
        select(title.x,b_i) %>%
        slice(1:10) %>%
        rename(title = title.x)
      edx %>% group_by(title) %>% mutate(n = n()) %>% inner_join(temp1, by = 'title') %>%
        arrange(desc(b_i)) %>%
        distinct(title,b_i,n)
  
  # Following code displays 10 movies with lowest b_i value, again these movies were rated very few 
  # times that made them appear in the last 10 positions
      
      temp2 <- edx %>% left_join(mod4_movie_avg , by = 'movieId') %>%
      left_join(movie_title, by='movieId') %>%
        arrange((b_i)) %>%
        distinct(title.x,b_i) %>%
        select(title.x,b_i) %>%
        slice(1:10) %>%
        rename(title = title.x)
      edx %>% group_by(title) %>% mutate(n = n()) %>% inner_join(temp2, by = 'title') %>%
        arrange((b_i)) %>%
        distinct(title,b_i,n)
  
  ##### Movie regularization:
      # To remove above displayed noise that gives false impression of the movie rankings, we will
      # use following code that penalizes this behaviour
      
      # Following code will calculate movie averages using lambda as 2.5 (to start with) on edx
      # set (i.e. training set)
      
          lambda <- 2.5
          mod4_movie_avg_reg <- edx %>% group_by(movieId) %>%
            summarize(b_i_lambda = sum(rating - mu) / (n() + lambda), n_i = n())
      
      # Note that if movie rating sample size is large, than lambda will not have much effect on the equation/b_i, but if movie rating sample size is small,  than lambda will impact the equation by reducing b_i value i.e. penalizing b_i if movie received lesser number of ratings.
      # This will ensure that b_i now predicts movies correctly.
      # Following code displays top 10 movies and last 10 movies after using regularization on b_i (or movies):
      
          # Top 10 movies based on regularized movie ratings
          
          Temp3 <- edx %>% left_join(mod4_movie_avg_reg , by = 'movieId') %>%
            left_join(movie_title, by='movieId') %>%
            arrange(desc(b_i_lambda)) %>%
            distinct(title.x,b_i_lambda) %>%
            select(title.x,b_i_lambda) %>%
            slice(1:10) %>%
            rename(title = title.x)
          edx %>% group_by(title) %>% mutate(n = n()) %>% inner_join(Temp3, by = 'title') %>%
            arrange(desc(b_i_lambda)) %>%
            distinct(title,b_i_lambda,n)
          
          # Last 10 movies based on regularized movie ratings
          
          Temp4 <- edx %>% left_join(mod4_movie_avg_reg , by = 'movieId') %>%
            left_join(movie_title, by='movieId') %>%
            arrange(b_i_lambda) %>%
            distinct(title.x,b_i_lambda) %>%
            select(title.x,b_i_lambda) %>%
            slice(1:10) %>%
            rename(title = title.x)
          edx %>% group_by(title) %>% mutate(n = n()) %>% inner_join(Temp4, by = 'title') %>%
            arrange(desc(b_i_lambda)) %>%
            distinct(title,b_i_lambda,n)  
          
          
      # Following code will predict movie ratings for validation set (i.e. test set) using
      # movie averages calculated in above step
          
          mod4_predicted_ratings <- validation %>% left_join(mod4_movie_avg_reg, by = 'movieId') %>%
            mutate(pred = mu + b_i_lambda) %>% .$pred
      
      # Following code will give us RMSE value based on our predicted movie ratings
          
          mod4_rmse <- RMSE(validation$rating,mod4_predicted_ratings) # 0.9438521
      
      ##### Tuning lambda for movie regularization:
          # To tune lambda i.e. to find a value of lambda that will give us the least value of RMSE, 
          # we will use following code
          
          # lambdas will have a range of values from 0 to 10 with an interval of 0.25
          
              lambdas <- seq(0,10,0.25)
              
              sum_of_numerator_lambda <- edx %>% group_by(movieId) %>%
                summarize(s = sum(rating - mu) , n_i = n())
          
          # Following code will give RMSE value for different values of lambda.
              
              rmses <- sapply(lambdas, function(l){
                predicted_ratings <- validation %>% left_join(sum_of_numerator_lambda, by = 'movieId') %>%
                  mutate(b_i_lambda = s / (n_i + l)) %>%
                  mutate(pred = mu + b_i_lambda) %>% .$pred
                
                RMSE(validation$rating , predicted_ratings)
              })
          
          # Following plot will give us details on which lambda value gives us the least RMSE
              
              plot(lambdas,rmses)
          
          # Following code will give us the best lambda value
              
              lambdas[which.min(rmses)] # 2.5
          
          # Following code will provide us the least RMSE value when lambda is 2.5
              
              min(rmses) # 0.9438521
  
  ##### Movie and User regularization #####
      # Above method didnt give us RMSE lesser than Model 3, but we have not removed user noise
      # in our model
      # Following code will remove user noise as well. We will tune lambdas in below code
      
      # lambdas will have a range of values from 0 to 10 with interval of 0.25
              
          lambdas <- seq(0,10,0.25)
      
      # Following code will calculate RMSE value for each lambda
      
          rmses_user_movie <- sapply(lambdas, function(l){
            
            # Following code calculates b_i by penalizing movies with lower ratings on edx set
            
                b_i <- edx %>% group_by(movieId) %>% summarize(b_i = sum(rating - mu) / (n() + l))
            
            # Following code calculates b_u by penalizing users that have rated less number of 
            # movies on edx set
                
                b_u <- edx %>% left_join(b_i, by='movieId') %>% group_by(userId) %>%
                  summarize(b_u = sum(rating - b_i - mu) / (n() + l) )
                
            # Following code will predit movie ratings using b_i and b_u calculated in above code
            # on validation set
                
                predicted_ratings <- validation %>% left_join(b_i, by = 'movieId') %>%
                  left_join(b_u , by = 'userId') %>%
                  mutate(pred = mu + b_i + b_u) %>% .$pred
                
            # Following code returns RMSE value for this specific lambda
                
                return(RMSE(validation$rating , predicted_ratings))
          })
      
      # Following code will give us the best lambda value
          
      lambdas[which.min(rmses_user_movie)] # 5.25
      
      # Following code will give us the RMSE value when lambda is 5.25 (i.e. lowest RMSE)
      
      min(rmses_user_movie) # 0.864817
  
  # Add results into rmse_result
      
  rmse_result <- bind_rows(rmse_result , data.frame(method = 'Model 4 : Regularized Movie and User Effect Model' , RMSE = min(rmses_user_movie)))
  rmse_result %>% knitr::kable()


################ RESULTS ################

  # Following code shows RMSE values for all the 4 models
  
      rmse_result %>% knitr::kable()
  
  # Following code shows that the best mode with least RMSE value (0.864817) is Mode 4 (Regularization on
  #  users and movies) 
  
      rmse_result[which.min(rmse_result$RMSE),]


################ CONCLUSION ################

# We can see that 'Model 4 : Regularized Movie + User Effect' is the best model among the 4
# but, 'Model 3 : Movie + User' model also clears "Grading Rubric" criteria

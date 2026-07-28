


pupil_epoch <- function(df,bf,event,num,pre,post,sub_name,strategy_name) {
  block_indices <- which(df$text == "block")
  post_position = post
  pre_position = pre
  step_size = post_position - pre_position
  
  if (length(block_indices) != length(bf$n_block)) {
    print(paste0("The number of blocks in pupil is less than the behaviour. Skipping : ",sub_name,' ',strategy_name))
    return(NULL)  # Skips the function and returns NULL
  }
  
  all_data <- list()
  
  for (i in seq_along(block_indices)) {
    
    block_index <- block_indices[i]
    
    # Define the upper limit: next block index if available, otherwise include all remaining indices
    upper_limit <- if (i < length(block_indices)) block_indices[i + 1] else length(df$text) + 1
    
    # Find trial indices occurring after the current block index
    trial_indices <- which(df$text == event & seq_along(df$text) > block_index & seq_along(df$text) < upper_limit)
    
    #if needed, populate
    trial_indices <- trial_indices + step_size * seq(0, num - 1)
    
    #initilizing the vectors
    pupil_sizes <- vector("list", step_size + 1)
    microsacc <- vector("list", step_size + 1)
    
    #pupil
    for (j in 0:step_size) {
      temp <- df$ps[trial_indices + j] # storing the jth position of the trial of this block
      pupil_sizes[[j+1]] <- mean(temp, na.rm = TRUE) #averaging the jth position
    }
    
    #microsaccade
    for (j in 0:step_size) {
      temp <- df$ms[trial_indices + j] # storing the jth position of the trial of this block
      microsacc[[j + 1]] <- mean(temp, na.rm = TRUE) #averaging the jth position
    }
    
    
    block_data <- data.frame(
      sub = sub_name,
      strategy = strategy_name,
      n_block = bf$n_block[i],
      position = pre_position:post_position,
      pupil_size = unlist(pupil_sizes),
      microsacc = unlist(microsacc),
      effort = round(bf$slider_effort.response[i],2),
      pac = bf$pac3[i],
      pac_low = bf$pac3_low[i],
      pac_high = bf$pac3_high[i],
      performance = bf$g[i],
      rt = bf$rt_h[i],
      n_back = bf$n_back[i]
    )
    all_data[[i]] <- block_data
  }
  return(do.call(rbind, all_data))
}

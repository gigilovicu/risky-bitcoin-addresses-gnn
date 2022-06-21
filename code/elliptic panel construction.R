library(tidyverse)
library(ids)

path <- ''

### 0 . READ DATA ###################
# ClovrLabs entities
entities <- read_csv(paste0(path, 'labels_ell_address.csv'), col_names = FALSE) %>%
            select(addresses = 1, id = 2, entity = 3, category = 4, class = 5)

# Raw elliptic transactions data from bitcoin
inputs <- read_csv(paste0(path, 'inputs.csv')) %>% select(-1) %>% left_join(entities, by = "addresses")
outputs <- read_csv(paste0(path, 'outputs.csv')) %>% select(-1) %>% left_join(entities, by = "addresses")
transactions <- read_csv(paste0(path, 'transactions.csv')) %>% select(-1) %>%
                mutate(block_timestamp = as.POSIXct(block_timestamp/1000, origin="1970-01-01"))

# Elliptic data
elliptic_classes_raw <- read_csv(paste0(path, 'original elliptic data/elliptic_txs_classes.csv'))
txn_elliptic_deanonymised <- read_csv(paste0(path, 'deanonymised_elliptic.csv'))

elliptic_features <- read_csv(paste0(path, 'original elliptic data/elliptic_txs_features.csv'), col_names = FALSE) %>% 
                     rename(txId = 1, timestep = 2)

### 1. CLASSIFICATION FROM ADDRESSES -> TRANSACTIONS ################
# Take class = 1 if at least 1 address in the transaction has a high risk label 
txn_inputs <- inputs %>% group_by(hash) %>% summarise(cnt = length(id),
                                                      id = unique(id),
                                                      entity = unique(entity),
                                                      category = unique(category),
                                                      class = unique(class)) 

txn_outputs <- outputs %>% group_by(hash, id) %>% summarise(cnt = length(id),
                                                            id = unique(id),
                                                            entity = unique(entity),
                                                            category = unique(category),
                                                            class = unique(class))

# Must deal with multiple classification of addresses in one transaction                  
txn_inputs_clean <- txn_inputs %>% ungroup() %>% group_by(hash) %>% 
                    filter(class == max(class, na.rm = TRUE)) 

txn_inputs_clean <-  txn_inputs %>% filter(is.na(id)) %>% anti_join(txn_inputs_clean, by = "hash") %>% 
                     bind_rows(txn_inputs_clean) %>% select(hash, entity_class_input = class) %>%
                     distinct(hash, entity_class_input)

# Must deal with multiple classification of addresses in one transaction              
txn_outputs_clean <- txn_outputs %>% ungroup() %>% group_by(hash) %>% 
                     filter(class == max(class, na.rm = TRUE)) 

txn_outputs_clean <-  txn_outputs %>% filter(is.na(id)) %>% anti_join(txn_outputs_clean, by = "hash") %>% 
                      bind_rows(txn_outputs_clean) %>% select(hash, entity_class_output = class) %>%
                      distinct(hash, entity_class_output)
                      
### 2. LINK TO ELLIPTIC CLASSES #################################
# Add deanonymised txns, join to Clovr Labs classification
elliptic_classes <- elliptic_classes_raw %>% left_join(txn_elliptic_deanonymised, by = "txId") %>%
                    select(transaction, class) %>%  mutate(class = str_replace_all(class, "2", "0"),
                                                           class = as.numeric(na_if(class, "unknown"))) %>%
                    filter(!is.na(transaction)) %>% left_join(txn_inputs_clean, by = c("transaction" = "hash")) %>% 
                    left_join(txn_outputs_clean, by = c("transaction" = "hash"))

# Combine classes -> any 1 then its a 1, then differentiate between input OR output and input AND output
# elliptic_classes <- elliptic_classes %>% group_by(transaction) %>%
#                     mutate(classes_combined = if_else(is.na(class) & is.na(entity_class_output) & is.na(entity_class_input),
#                                                       as.numeric(NA),
#                                                       sum(class,
#                                                           entity_class_input,
#                                                           entity_class_output, na.rm = TRUE)),
#                            classes_combined = if_else(classes_combined == 3, 2, classes_combined)) %>%
#                     rename(class_elliptic = class)

# Inputs only -> if there is a 1 on the input address, then classify as a 1
elliptic_classes <- elliptic_classes %>% group_by(transaction) %>%
                    mutate(classes_combined = if_else(is.na(class) & is.na(entity_class_input),
                                                      as.numeric(NA),
                                                      sum(class,
                                                          entity_class_input, na.rm = TRUE)),
                           classes_combined = if_else(classes_combined == 2, 1, classes_combined)) %>%
                    rename(class_elliptic = class)

# Clean up and map new classifications back to txId
elliptic_classes_final <- elliptic_classes_raw %>% left_join(txn_elliptic_deanonymised, by = "txId") %>% select(-class) %>%  
                          left_join(elliptic_classes %>% select(transaction, classes_combined), by = "transaction") %>%
                          select(-transaction) %>% rename(class = classes_combined)

write_csv(elliptic_classes_final, paste0(path, "original elliptic data/elliptic_txs_classes_augmented.csv"))

summary_combined_classes <- elliptic_classes %>% ungroup() %>% group_by(classes_combined) %>% summarise(share_txns = n()/nrow(elliptic_classes))                             

### 3. GENERATE ADDRESS LEVEL PANEL FROM ELLIPTIC DATA #########################

# Map elliptic transaction classifications to addresses
inputs_elliptic <- inputs %>% left_join(elliptic_classes %>% select(transaction, class_elliptic),
                                        by = c("hash" = "transaction")) %>% 
                   mutate(classes_combined = coalesce(class, class_elliptic))


# Map elliptic transaction classifications to addresses
# outputs_elliptic <- outputs %>% left_join(elliptic_classes %>% select(transaction, class_elliptic),
#                                           by = c("hash" = "transaction")) %>% 
#                    mutate(classes_combined = coalesce(class, class_elliptic))

# Timesteps
transactions <- transactions %>% left_join(elliptic_features %>% select(txId, timestep) %>%
                                           right_join(txn_elliptic_deanonymised, by = "txId") %>%
                                           select(-txId), by = c("hash" = "transaction")) 

# Construct the panel, apportioning amounts based on output_shares 
construct_panel <- function(inputs, outputs, transactions) {
  
  inputs <- inputs %>% select(txn_hash = hash, input_address = addresses, txn_amount = value,
                              class = classes_combined) %>% 
            group_by(txn_hash) %>% mutate(total_input = sum(txn_amount),
                                          input_share = txn_amount/total_input, class) %>% ungroup()
  
  outputs <- outputs %>% select(txn_hash = hash, output_address = addresses, txn_amount = value,
                                class) %>%  #= classes_combined) %>% 
             group_by(txn_hash) %>% mutate(total_output = sum(txn_amount),
                                           output_share = txn_amount/total_output) %>% ungroup() %>% 
             filter(txn_amount != 0)
  
  panel <- inputs %>% full_join(outputs, by = "txn_hash") %>%
           mutate(total_fee = input_share*(total_input - total_output),
                  txn_amount = (txn_amount.x - total_fee)*output_share,
                  fee = total_fee*output_share) %>% ungroup() %>% rowwise() %>%
           mutate(class = if_else(is.na(class.x) & is.na(class.y), as.numeric(NA), sum(class.x, class.y, na.rm = TRUE))) %>% 
           left_join(transactions %>% select(txn_hash = hash, timestep, block_timestamp), by = "txn_hash") %>% 
           select(txn_hash, timestep, block_timestamp, input_address, output_address, txn_amount, fee, class) %>% 
           filter(!is.na(input_address)) %>% ungroup() #remove coinbase txns
  return(panel)  
}

panel <- construct_panel(inputs = inputs_elliptic, outputs = outputs, transactions = transactions)

#Create unique IDs for addresses to to significantly reduce size of the file we are dealing with
set.seed(1993)
address_ids <- panel %>% select(input_address, output_address) %>% mutate(a = 0) %>%
               pivot_longer(-a, names_to = "type", values_to = "address") %>% select(-c(a, type)) %>% 
               distinct() %>% mutate(address_id = random_id(n = length(address), bytes = 5))

entities_match <- entities %>% left_join(address_ids %>% select(address, address_id),
                                         by = c("addresses" = "address"))

write_csv(entities_match, paste0(path, 'entities_match_id.csv'))

# Join ids to panel for addresses and txn_hash
panel <- panel %>% left_join(address_ids, by = c("input_address" = "address")) %>% select(-input_address) %>%
         rename(input_address = address_id) %>% left_join(address_ids, by = c("output_address" = "address")) %>% 
         select(-output_address) %>% rename(output_address = address_id) %>%
         left_join(txn_elliptic_deanonymised, by = c("txn_hash" = "transaction")) %>% select(-txn_hash) %>%
         left_join(entities_match %>% select(address_id, entity, category), by = c("input_address" = "address_id"))

write_csv(panel, paste0(path, "elliptic_panel_new.csv"))


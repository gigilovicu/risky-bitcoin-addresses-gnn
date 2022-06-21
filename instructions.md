This provides instructions on how to generate the data and run the models accompanying this thesis.

Data files
- inputs.csv (output code 1)
- outputs.csv
- transactions.csv
- elliptic_txs_features.csv (https://www.kaggle.com/datasets/ellipticco/elliptic-data-set)
- elliptic_txs_edgelist.csv
- elliptic_txs_classes.csv
- elliptic_txs_classes_augmented_input.csv (output code 2)
- deanonymised_elliptic.csv (https://www.kaggle.com/datasets/alexbenzik/deanonymized-995-pct-of-elliptic-transactions)


Code files (to be run in order)
1. bitcoin-transactions-download.ipynb. Notebook to download raw transaction data underlying Elliptic data set. Outputs inputs.csv, outputs.csv and transactions.csv. It is not necessary to run this code we have provided the outputs.
2. elliptic panel construction.R. Notebook that takes inputs.csv, outputs.csv, transactions.csv, ellitpic_txs_classes.csv, labels_ell_address.csv and deanonymised_elliptic.csv as input and constructs panel of pairwise input address/output address combinations. Outputs elliptic_panel_new.csv. Also outputs transaction labels from elliptic and clovr labs combined: elliptic_txs_classes_augmented_input.csv (provided).
3. elliptic address data.R. Takes elliptic_panel_new.csv as input and constructs node feature dataframe and edge list with attributes for sub-graphs. Outputs node_address_features.csv and edgelist_hop3_input.csv.
4. load address graphs.ipynb. Takes node_address_features.csv and edgelist_hop3_input.csv and constructs subgraph objects for passing to pytorch geoemtric. In addition, conducts training/test split of subgraphs and undersamples training set. Outputs address_subgraphs.pkl
5. transaction_level_all.ipynb. Takes as input elliptic_txs_*.csv files to run models.
6. address_level_all.ipynb. Takes address_subgraphs.pkl as input and runs models.
7. summary stats.ipynb. Overall statistics on elliptic anc clover dataset labels
8. graph_classification_plots.ipynb. This code executes three tasks: 1) calculates value amounts for precision and recall 2) plots subgraphs by category and 3) producess mean statistics on subgraphs by type (low risk, high risk, correctly/incorrectly predicted,)

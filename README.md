# A project exploring how to predict high risk Bitcoin addresses using the Elliptic dataset

We use a labelled dataset of Bitcoin transactions to test different approaches to detecting
high risk activity. Our data is based on the stylised Elliptic dataset (Weber et al., 2019), which contains
around 200,000 Bitcoin transactions from 2016 to 2017, a portion of which are labelled illicit and licit
(which we relabel to high and low risk). We extract the full set of raw data underlying the transactions
directly from the blockchain. We then combine the Elliptic data with another set of labels identifying high
and low risk counterparties (obtained from a Barcelona-based crypto security firm, Clovr Labs). Finally,
we use this augmented data to construct two types of datasets: a transaction-level dataset — that follows
the approach of the rest of the literature — and a novel address-level dataset. The address-level dataset
has the advantage of being able to identify risky activity at the counterparty level. Both datasets are
highly imbalanced away from high risk observations, which is a typical problem faced in risk detection
exercises in finance (i.e. the vast majority of transactions are low risk). We acknowledge that these data
are somewhat dated, given Bitcoin is significantly more mainstream in 2022 than in 2017, and that this
could affect the external validity of our results.

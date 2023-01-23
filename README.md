# shuffleOracleSQL

Oracle doesn't provide functions for shuffling the data of your tables. 
These two files return a pl/sql code that shuffles the data of one column of your table and all others remain the same.
The first one (fastShuffle) do it in the most optimal way. It executes fine if the table does not have a unique constraint.
If it does, its safer to execute the shuffleUnique, as it deals with all problems related with unique constraints, including if there are more than one unique constraint.

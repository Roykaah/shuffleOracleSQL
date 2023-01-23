# shuffleOracleSQL

<p>Oracle doesn't provide functions for shuffling the data of your tables. </p>
<p>These two files return a pl/sql code that shuffles the data of one column of your table while all others remain the same.</p>
<p>The first one (fastShuffle) do it in the most optimal way. It executes fine if the table does not have a unique constraint.</p>
<p>If it does, its safer to execute the shuffleUnique, as it deals with all the problems related with unique constraints, including if there are more than one constraint.</p>

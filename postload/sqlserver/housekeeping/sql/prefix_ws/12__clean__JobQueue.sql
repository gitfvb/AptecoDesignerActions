DELETE
  FROM [JobQueue]
  where TimeAdded < dateadd(week,-2,getdate())
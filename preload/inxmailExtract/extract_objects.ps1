[System.Collections.ArrayList]@(
    [PSCustomObject]@{
        "object" = "lists" #/lists{?createdAfter,createdBefore}
        "extract" = @(
            "full" = [PSCustomObject]@{
                # no more parameters
            }
            "delta" = [PSCustomObject]@{
                "createdAfter" = "xxx"
            }

        ) #full|delta
    }
    <#

    https://apidocs.inxmail.com/xpro/rest/v1/

    list settings not available to read on 2021-06-11
    /mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,types,listIds,readyToSend,embedded}
    /regular-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,sentBefore,types,listIds,readyToSend,mailingStates,embedded},
    /split-test-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds,readyToSend}
    /action-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds}
    /trigger-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds}
    /subscription-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds,readyToSend}
    /mailings/{mailingId}/approvals
    /mailings/{id}/links{?types}
    /links{?mailingIds,types}
    /sendings{?mailingIds,listIds,sendingsFinishedBeforeDate,sendingsFinishedAfterDate}
    /sendings/{sendingId}/protocol
    /attributes
    /recipients{?attributes,subscribedTo,lastModifiedSince,email,attributes.attributeName,trackingPermissionsForLists,subscriptionDatesForLists,unsubscriptionDatesForLists}
    /test-profiles{?listIds,types,allAttributes}
    /events/subscriptions{?listId,startDate,endDate,types,embedded,recipientAttributes}
    /events/unsubscriptions{?listIds,startDate,endDate,types,embedded,recipientAttributes}
    /imports/recipients/{importId}/files
    /imports/recipients/{importId}/files/{importFileId}/errors
    /bounces{?startDate,endDate,embedded,bounceCategory,listId,mailingId,sendingIds,recipientAttributes}
    /bounces{?startDate,endDate,embedded,bounceCategory,mailingIds,sendingIds,listIds,recipientAttributes}
    /clicks{?sendingId,mailingId,trackedOnly,embedded,startDate,endDate,recipientAttributes,listIds}
    /clicks{?sendingId,trackedOnly,embedded,startDate,endDate,recipientAttributes,mailingIds,listIds}
    /web-beacon-hits{?sendingId,mailingIds,listIds,trackedOnly,embedded,startDate,endDate,recipientAttributes}
    /blacklist-entries{?lastModifiedSince}
    /statistics/responses{?mailingId}
    /statistics/sendings{?mailingId}
    /text-modules{?listId}
    /test-mail-groups
    




    Please note that both request parameters sendingsFinishedBeforeDate and sendingsFinishedAfterDate
    are not recommended to be used for continuous synchronisations. For continuous synchronisation use
    id-based requests to avoid problems of date based synchronization. For this purpose each time you
    reach the last page of a collection you find a link to next page you should request in your next
    scheduled synchronization. A possible problem of date based synchronization could be that most recent
    data is not yet available and would be missed if you request a specific date-time range. For further
    information please read: Long term data synchronization with the upcoming link. https://apidocs.inxmail.com/xpro/rest/v1/#synchronizing

    Long term data synchronization with the upcoming link

    A typical use case is the synchronization of data, where you only want to get new objects in subsequent
    synchronizations. Over longer periods of time, there may be huge amounts of data and the practical way of
    synchronizing is to only look at new data.

    To accommodate this, this API provides a special link on the last page of a collection resource. You can
    save this link and use it as a starting point for a future synchronization. The upcoming link leads to a page
    immediately following your last synchronized page of data. This page will be empty until data is entered into the system.

    Please be aware, new data may not become available instantly upon being entered into the system, as it may be
    stored in write buffers for a while.

    We strongly discourage synchronization based on timestamps for a number of reasons, including write buffers and
    unsynchronized clocks.

    Please also mind, the upcoming link will only return a collection containing new objects, it will not return
    previously retrieved objects, even if they have been changed. If you want to capture all changes to all objects
    of a given type, just get the resource collection of this type.

    If no new data has been entered into the system, following the upcoming link will return an empty collection.

    self            The canonical link to this page.
    first           The link relation for the first page of results.
    next            The link relation for the immediate next page of results.
    inx:upcoming    Links to a possible next page. This next page is only available once further data has been created in the system.

    #>
)
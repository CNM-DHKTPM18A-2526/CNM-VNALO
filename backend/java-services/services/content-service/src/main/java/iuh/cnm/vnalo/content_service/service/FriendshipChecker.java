package iuh.cnm.vnalo.content_service.service;

import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class FriendshipChecker {

    private final EntityManager entityManager;
    private final CoreFriendshipClient coreFriendshipClient;
    private final RequestAuthorizationHolder requestAuthorizationHolder;

    public Set<UUID> findFriendIds(UUID userId) {
        Set<UUID> friendIds = new HashSet<>(findFriendIdsFromDatabase(userId));

        if (coreFriendshipClient.isEnabled()) {
            String authorization = requestAuthorizationHolder.getAuthorizationHeader();
            friendIds.addAll(coreFriendshipClient.fetchFriendIds(authorization));
        }

        return friendIds;
    }

    public boolean areFriends(UUID userA, UUID userB) {
        if (userA == null || userB == null) {
            return false;
        }
        if (userA.equals(userB)) {
            return true;
        }
        return findFriendIds(userA).contains(userB);
    }

    private Set<UUID> findFriendIdsFromDatabase(UUID userId) {
        if (userId == null) {
            return Set.of();
        }

        @SuppressWarnings("unchecked")
        List<Object> rows = entityManager.createNativeQuery("""
                        SELECT CASE
                            WHEN f.user_id_from = :userId THEN f.user_id_to
                            ELSE f.user_id_from
                        END
                        FROM public.friendship f
                        WHERE f.user_id_from = :userId OR f.user_id_to = :userId
                        """)
                .setParameter("userId", userId)
                .getResultList();

        Set<UUID> friendIds = new HashSet<>();
        for (Object row : rows) {
            if (row instanceof UUID uuid) {
                friendIds.add(uuid);
            } else if (row != null) {
                friendIds.add(UUID.fromString(row.toString()));
            }
        }
        return friendIds;
    }
}

-- V2__add_foreign_keys.sql
-- Add foreign key constraints for referential integrity

-- Auth refresh token -> Auth account
ALTER TABLE auth_refresh_token
    ADD CONSTRAINT fk_refresh_token_account
    FOREIGN KEY (account_id) REFERENCES auth_account(id) ON DELETE CASCADE;

-- User profile -> Auth account (1:1 relationship, same ID)
ALTER TABLE user_profile
    ADD CONSTRAINT fk_profile_account
    FOREIGN KEY (id) REFERENCES auth_account(id) ON DELETE CASCADE;

-- User privacy setting -> User profile
ALTER TABLE user_privacy_setting
    ADD CONSTRAINT fk_privacy_profile
    FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;

-- Friend request -> User profile (sender)
ALTER TABLE friend_request
    ADD CONSTRAINT fk_friend_request_from
    FOREIGN KEY (user_id_from) REFERENCES user_profile(id) ON DELETE CASCADE;

-- Friend request -> User profile (recipient)
ALTER TABLE friend_request
    ADD CONSTRAINT fk_friend_request_to
    FOREIGN KEY (user_id_to) REFERENCES user_profile(id) ON DELETE CASCADE;

-- Friendship -> User profile (user from)
ALTER TABLE friendship
    ADD CONSTRAINT fk_friendship_from
    FOREIGN KEY (user_id_from) REFERENCES user_profile(id) ON DELETE CASCADE;

-- Friendship -> User profile (user to)
ALTER TABLE friendship
    ADD CONSTRAINT fk_friendship_to
    FOREIGN KEY (user_id_to) REFERENCES user_profile(id) ON DELETE CASCADE;

-- Block list -> User profile (blocker)
ALTER TABLE block_list
    ADD CONSTRAINT fk_block_blocker
    FOREIGN KEY (blocker_id) REFERENCES user_profile(id) ON DELETE CASCADE;

-- Block list -> User profile (blocked)
ALTER TABLE block_list
    ADD CONSTRAINT fk_block_blocked
    FOREIGN KEY (blocked_id) REFERENCES user_profile(id) ON DELETE CASCADE;

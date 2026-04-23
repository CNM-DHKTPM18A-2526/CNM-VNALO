import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { InboxService } from '../src/inbox/inbox.service';
import { ConversationInbox } from '../src/entities/conversation-inbox.entity';
import { Conversation } from '../src/entities/conversation.entity';
import { ConversationMember } from '../src/entities/conversation-member.entity';

describe('InboxService', () => {
  let service: InboxService;
  let inboxRepo: jest.Mocked<Repository<ConversationInbox>>;

  beforeEach(async () => {
    const mockRepo = () => ({
      createQueryBuilder: jest.fn(),
      find: jest.fn(),
      getMany: jest.fn(),
    });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InboxService,
        {
          provide: getRepositoryToken(ConversationInbox),
          useFactory: mockRepo,
        },
        { provide: getRepositoryToken(Conversation), useFactory: mockRepo },
        {
          provide: getRepositoryToken(ConversationMember),
          useFactory: mockRepo,
        },
      ],
    }).compile();

    service = module.get(InboxService);
    inboxRepo = module.get(getRepositoryToken(ConversationInbox));
  });

  describe('getTotalUnreadCount', () => {
    it('should return 0 when restricted web mode', async () => {
      const result = await service.getTotalUnreadCount('user-1', {
        clientPlatform: 'WEB',
        restrictedWebMode: true,
        loginAtEpochSec: 100,
      });
      expect(result).toBe(0);
      expect(inboxRepo.createQueryBuilder).not.toHaveBeenCalled();
    });
  });
});

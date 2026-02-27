import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { MessageService } from '../src/message/message.service';
import { Message, MessageType, MessageStatus } from '../src/entities/message.entity';
import { MessageReaction } from '../src/entities/message-reaction.entity';
import { PinnedMessage } from '../src/entities/pinned-message.entity';
import { ConversationInbox } from '../src/entities/conversation-inbox.entity';
import { ConversationMember, MemberRole } from '../src/entities/conversation-member.entity';
import { ConversationService } from '../src/conversation/conversation.service';
import { ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';

// Redis mock token used by @nestjs-modules/ioredis
const IOREDIS_TOKEN = 'default_IORedisModuleConnectionToken';

describe('MessageService', () => {
  let service: MessageService;
  let messageRepo: jest.Mocked<Repository<Message>>;
  let reactionRepo: jest.Mocked<Repository<MessageReaction>>;
  let pinRepo: jest.Mocked<Repository<PinnedMessage>>;
  let inboxRepo: jest.Mocked<Repository<ConversationInbox>>;
  let memberRepo: jest.Mocked<Repository<ConversationMember>>;
  let conversationService: jest.Mocked<ConversationService>;
  let redisMock: Record<string, jest.Mock>;

  const userId = '11111111-1111-1111-1111-111111111111';
  const convId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const msgId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  beforeEach(async () => {
    const mockQueryBuilder = {
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getRawOne: jest.fn().mockResolvedValue({ maxSeq: '0' }),
      getCount: jest.fn().mockResolvedValue(0),
      insert: jest.fn().mockReturnThis(),
      into: jest.fn().mockReturnThis(),
      values: jest.fn().mockReturnThis(),
      orUpdate: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({}),
    };

    const mockRepo = () => ({
      findOne: jest.fn(),
      find: jest.fn(),
      save: jest.fn(),
      create: jest.fn().mockImplementation((data) => data),
      delete: jest.fn().mockResolvedValue({ affected: 0 }),
      remove: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
      createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
    });

    redisMock = {
      exists: jest.fn().mockResolvedValue(1),
      setnx: jest.fn().mockResolvedValue(1),
      incr: jest.fn().mockResolvedValue(1),
    };

    const mockDataSource = {
      transaction: jest.fn().mockImplementation(async (cb) => {
        const mockManager = {
          create: jest.fn().mockImplementation((_entity, data) => data),
          save: jest.fn().mockImplementation((data) => Promise.resolve({ id: msgId, ...data, createdAt: new Date() })),
          findOne: jest.fn().mockResolvedValue(null),
          find: jest.fn().mockResolvedValue([]),
          createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
        };
        return cb(mockManager);
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MessageService,
        { provide: getRepositoryToken(Message), useFactory: mockRepo },
        { provide: getRepositoryToken(MessageReaction), useFactory: mockRepo },
        { provide: getRepositoryToken(PinnedMessage), useFactory: mockRepo },
        { provide: getRepositoryToken(ConversationInbox), useFactory: mockRepo },
        { provide: getRepositoryToken(ConversationMember), useFactory: mockRepo },
        {
          provide: ConversationService,
          useValue: { assertMember: jest.fn().mockResolvedValue({ userId, role: MemberRole.MEMBER, lastReadSeq: 5 }) },
        },
        { provide: DataSource, useValue: mockDataSource },
        { provide: IOREDIS_TOKEN, useValue: redisMock },
      ],
    }).compile();

    service = module.get<MessageService>(MessageService);
    messageRepo = module.get(getRepositoryToken(Message));
    reactionRepo = module.get(getRepositoryToken(MessageReaction));
    pinRepo = module.get(getRepositoryToken(PinnedMessage));
    inboxRepo = module.get(getRepositoryToken(ConversationInbox));
    memberRepo = module.get(getRepositoryToken(ConversationMember));
    conversationService = module.get(ConversationService);
  });

  describe('sendMessage', () => {
    it('should create and return a new message via transaction', async () => {
      const dto = { conversationId: convId, content: 'Hello!', messageType: MessageType.TEXT };
      messageRepo.findOne.mockResolvedValue(null); // no idempotency hit

      const result = await service.sendMessage(userId, dto);
      expect(result.id).toBe(msgId);
      expect(conversationService.assertMember).toHaveBeenCalledWith(convId, userId);
      expect(redisMock.incr).toHaveBeenCalled();
    });

    it('should return existing message if clientMessageId matches (idempotency)', async () => {
      const clientId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
      const existingMsg = { id: msgId, clientMessageId: clientId, senderId: userId };
      messageRepo.findOne.mockResolvedValue(existingMsg as any);

      const result = await service.sendMessage(userId, { conversationId: convId, clientMessageId: clientId, content: 'Hello!' });
      expect(result.id).toBe(msgId);
    });

    it('should reject TEXT messages without content', async () => {
      const dto = { conversationId: convId, content: '', messageType: MessageType.TEXT };
      messageRepo.findOne.mockResolvedValue(null);

      await expect(service.sendMessage(userId, dto)).rejects.toThrow(BadRequestException);
    });

    it('should reject IMAGE messages without mediaUrl', async () => {
      const dto = { conversationId: convId, messageType: MessageType.IMAGE };
      messageRepo.findOne.mockResolvedValue(null);

      await expect(service.sendMessage(userId, dto)).rejects.toThrow(BadRequestException);
    });
  });

  describe('editMessage', () => {
    it('should edit own message', async () => {
      const msg = { id: msgId, senderId: userId, status: MessageStatus.SENT, content: 'old' };
      messageRepo.findOne.mockResolvedValue(msg as any);
      messageRepo.save.mockResolvedValue({ ...msg, content: 'new', isEdited: true } as any);

      const result = await service.editMessage(userId, msgId, 'new');
      expect(result.content).toBe('new');
      expect(result.isEdited).toBe(true);
    });

    it('should throw if editing other user message', async () => {
      const otherUserId = '33333333-3333-3333-3333-333333333333';
      messageRepo.findOne.mockResolvedValue({ id: msgId, senderId: otherUserId } as any);
      await expect(service.editMessage(userId, msgId, 'hack')).rejects.toThrow(ForbiddenException);
    });

    it('should throw if editing recalled message', async () => {
      messageRepo.findOne.mockResolvedValue({ id: msgId, senderId: userId, status: MessageStatus.RECALLED } as any);
      await expect(service.editMessage(userId, msgId, 'test')).rejects.toThrow(BadRequestException);
    });
  });

  describe('recallMessage', () => {
    it('should recall own message within time limit', async () => {
      const msg = {
        id: msgId, senderId: userId, status: MessageStatus.SENT,
        content: 'hello', conversationId: convId, serverSeq: 1,
        createdAt: new Date(), // Just created — within 24h limit
      };
      messageRepo.findOne
        .mockResolvedValueOnce(msg as any)  // findMessageOrFail
        .mockResolvedValueOnce(null);       // updateInboxPreviewAfterRecall - findOne prev msg
      messageRepo.save.mockResolvedValue({ ...msg, status: MessageStatus.RECALLED, content: null } as any);
      pinRepo.delete.mockResolvedValue({ affected: 0 } as any);
      reactionRepo.delete.mockResolvedValue({ affected: 0 } as any);

      const result = await service.recallMessage(userId, msgId);
      expect(result.status).toBe(MessageStatus.RECALLED);
      expect(result.content).toBeNull();
      expect(pinRepo.delete).toHaveBeenCalledWith({ messageId: msgId });
      expect(reactionRepo.delete).toHaveBeenCalledWith({ messageId: msgId });
    });

    it('should throw if recalling other user message', async () => {
      messageRepo.findOne.mockResolvedValue({ id: msgId, senderId: 'other-user' } as any);
      await expect(service.recallMessage(userId, msgId)).rejects.toThrow(ForbiddenException);
    });

    it('should throw if recalling already recalled message', async () => {
      messageRepo.findOne.mockResolvedValue({
        id: msgId, senderId: userId, status: MessageStatus.RECALLED, createdAt: new Date(),
      } as any);
      await expect(service.recallMessage(userId, msgId)).rejects.toThrow(BadRequestException);
    });

    it('should throw if message is older than 24 hours', async () => {
      const oldDate = new Date(Date.now() - 25 * 60 * 60 * 1000); // 25 hours ago
      messageRepo.findOne.mockResolvedValue({
        id: msgId, senderId: userId, status: MessageStatus.SENT, createdAt: oldDate,
      } as any);
      await expect(service.recallMessage(userId, msgId)).rejects.toThrow(BadRequestException);
    });
  });

  describe('addReaction', () => {
    it('should upsert a reaction to a message', async () => {
      messageRepo.findOne.mockResolvedValue({
        id: msgId, conversationId: convId, serverSeq: 1, status: MessageStatus.SENT,
      } as any);
      reactionRepo.upsert.mockResolvedValue(undefined as any);
      reactionRepo.findOne.mockResolvedValue({ messageId: msgId, userId, emoji: '👍' } as any);

      const result = await service.addReaction(userId, msgId, '👍');
      expect(result!.emoji).toBe('👍');
      expect(reactionRepo.upsert).toHaveBeenCalled();
    });

    it('should throw if reacting to recalled message', async () => {
      messageRepo.findOne.mockResolvedValue({
        id: msgId, conversationId: convId, status: MessageStatus.RECALLED,
      } as any);
      await expect(service.addReaction(userId, msgId, '👍')).rejects.toThrow(BadRequestException);
    });
  });

  describe('markAsRead', () => {
    it('should update lastReadSeq when advancing', async () => {
      const member = { userId, conversationId: convId, lastReadSeq: 5 };
      conversationService.assertMember.mockResolvedValue(member as any);
      memberRepo.save.mockResolvedValue({ ...member, lastReadSeq: 10 } as any);

      await service.markAsRead(userId, convId, 10);
      expect(memberRepo.save).toHaveBeenCalled();
      expect(inboxRepo.update).toHaveBeenCalled();
    });

    it('should not update if lastReadSeq is not advancing', async () => {
      conversationService.assertMember.mockResolvedValue({ userId, lastReadSeq: 10 } as any);

      await service.markAsRead(userId, convId, 5);
      expect(memberRepo.save).not.toHaveBeenCalled();
    });
  });
});

import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ConversationService } from '../src/conversation/conversation.service';
import { Conversation, ConversationType, JoinMode } from '../src/entities/conversation.entity';
import { ConversationMember, MemberRole } from '../src/entities/conversation-member.entity';
import { ConversationDirectMap } from '../src/entities/conversation-direct-map.entity';
import { ConversationJoinRequest } from '../src/entities/conversation-join-request.entity';
import { ConversationInbox } from '../src/entities/conversation-inbox.entity';
import { BadRequestException, ForbiddenException } from '@nestjs/common';

describe('ConversationService', () => {
  let service: ConversationService;
  let conversationRepo: jest.Mocked<Repository<Conversation>>;
  let memberRepo: jest.Mocked<Repository<ConversationMember>>;
  let directMapRepo: jest.Mocked<Repository<ConversationDirectMap>>;
  let joinRequestRepo: jest.Mocked<Repository<ConversationJoinRequest>>;
  let dataSource: jest.Mocked<DataSource>;

  const mockUserId = '11111111-1111-1111-1111-111111111111';
  const mockTargetId = '22222222-2222-2222-2222-222222222222';
  const mockConvId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  beforeEach(async () => {
    const mockQueryBuilder = {
      insert: jest.fn().mockReturnThis(),
      values: jest.fn().mockReturnThis(),
      orIgnore: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({}),
    };

    const mockRepo = () => ({
      findOne: jest.fn(),
      find: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
      count: jest.fn(),
      delete: jest.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
    });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ConversationService,
        { provide: getRepositoryToken(Conversation), useFactory: mockRepo },
        { provide: getRepositoryToken(ConversationMember), useFactory: mockRepo },
        { provide: getRepositoryToken(ConversationDirectMap), useFactory: mockRepo },
        { provide: getRepositoryToken(ConversationJoinRequest), useFactory: mockRepo },
        { provide: getRepositoryToken(ConversationInbox), useFactory: mockRepo },
        {
          provide: DataSource,
          useValue: {
            transaction: jest.fn((cb) =>
              cb({
                create: jest.fn().mockImplementation((_, data) => ({ id: mockConvId, ...data })),
                save: jest.fn().mockImplementation((_, data) => {
                  if (Array.isArray(data)) return data;
                  return { id: mockConvId, ...data };
                }),
                delete: jest.fn().mockResolvedValue({ affected: 1 }),
              }),
            ),
          },
        },
      ],
    }).compile();

    service = module.get<ConversationService>(ConversationService);
    conversationRepo = module.get(getRepositoryToken(Conversation));
    memberRepo = module.get(getRepositoryToken(ConversationMember));
    directMapRepo = module.get(getRepositoryToken(ConversationDirectMap));
    joinRequestRepo = module.get(getRepositoryToken(ConversationJoinRequest));
    dataSource = module.get(DataSource);

    memberRepo.count.mockResolvedValue(2);
  });

  describe('createDirect', () => {
    it('should throw if creating conversation with yourself', async () => {
      await expect(service.createDirect(mockUserId, mockUserId)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should return existing conversation if direct map exists', async () => {
      const existingMap = { userId1: mockUserId, userId2: mockTargetId, conversationId: mockConvId };
      directMapRepo.findOne.mockResolvedValue(existingMap as any);
      conversationRepo.findOne.mockResolvedValue({ id: mockConvId, type: ConversationType.DIRECT } as any);
      memberRepo.findOne.mockResolvedValue({ conversationId: mockConvId, userId: mockUserId } as any);
      memberRepo.find.mockResolvedValue([]);

      const result = await service.createDirect(mockUserId, mockTargetId);
      expect(result.id).toBe(mockConvId);
      expect(dataSource.transaction).not.toHaveBeenCalled();
    });

    it('should create new conversation if no direct map exists', async () => {
      directMapRepo.findOne.mockResolvedValue(null);
      // After transaction, getConversation will be called
      conversationRepo.findOne.mockResolvedValue({ id: mockConvId, type: ConversationType.DIRECT } as any);
      memberRepo.findOne.mockResolvedValue({ conversationId: mockConvId, userId: mockUserId } as any);
      memberRepo.find.mockResolvedValue([]);

      const result = await service.createDirect(mockUserId, mockTargetId);
      expect(dataSource.transaction).toHaveBeenCalled();
    });
  });

  describe('assertMember', () => {
    it('should throw ForbiddenException if user is not a member', async () => {
      memberRepo.findOne.mockResolvedValue(null);
      await expect(service.assertMember(mockConvId, mockUserId)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should return member if active', async () => {
      const member = { conversationId: mockConvId, userId: mockUserId, role: MemberRole.MEMBER, leftAt: null };
      memberRepo.findOne.mockResolvedValue(member as any);
      const result = await service.assertMember(mockConvId, mockUserId);
      expect(result.userId).toBe(mockUserId);
    });
  });

  describe('updateGroup', () => {
    it('should throw if conversation is DIRECT', async () => {
      conversationRepo.findOne.mockResolvedValue({ id: mockConvId, type: ConversationType.DIRECT } as any);
      await expect(service.updateGroup(mockConvId, mockUserId, { title: 'test' })).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw if user is not admin/owner', async () => {
      conversationRepo.findOne.mockResolvedValue({ id: mockConvId, type: ConversationType.GROUP } as any);
      memberRepo.findOne.mockResolvedValue({ role: MemberRole.MEMBER } as any);
      await expect(service.updateGroup(mockConvId, mockUserId, { title: 'test' })).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('addMembers', () => {
    it('should create pending approvals for APPROVAL groups when requester is MEMBER', async () => {
      conversationRepo.findOne.mockResolvedValue({
        id: mockConvId,
        type: ConversationType.GROUP,
        joinMode: JoinMode.APPROVAL,
        allowMemberInvite: true,
        memberLimit: 100,
      } as any);

      memberRepo.findOne
        .mockResolvedValueOnce({ userId: mockUserId, role: MemberRole.MEMBER, leftAt: null } as any)
        .mockResolvedValueOnce(null as any)
        .mockResolvedValueOnce({ userId: mockUserId, role: MemberRole.MEMBER, leftAt: null } as any);

      memberRepo.find.mockResolvedValue([] as any);

      const result = await service.addMembers(mockConvId, mockUserId, [mockTargetId]);

      expect(result.status).toBe('PENDING_APPROVAL');
      expect(result.pendingApprovals).toContain(mockTargetId);
      expect(joinRequestRepo.createQueryBuilder).toHaveBeenCalled();
    });
  });

  describe('requestJoin', () => {
    it('should create a pending request for APPROVAL mode', async () => {
      conversationRepo.findOne.mockResolvedValue({
        id: mockConvId,
        type: ConversationType.GROUP,
        joinMode: JoinMode.APPROVAL,
        memberLimit: 100,
      } as any);
      memberRepo.findOne.mockResolvedValue(null as any);

      const result = await service.requestJoin(mockConvId, mockTargetId);
      expect(result.status).toBe('PENDING_APPROVAL');
      expect(joinRequestRepo.createQueryBuilder).toHaveBeenCalled();
    });
  });

  describe('getMembers', () => {
    it('should require requester to be a member', async () => {
      memberRepo.findOne.mockResolvedValue(null as any);
      await expect(service.getMembers(mockConvId, mockUserId)).rejects.toThrow(ForbiddenException);
    });
  });

  describe('removeMember', () => {
    it('should throw if non-admin tries to remove another member', async () => {
      memberRepo.findOne
        .mockResolvedValueOnce({ userId: mockUserId, role: MemberRole.MEMBER, leftAt: null } as any)
        .mockResolvedValueOnce({ userId: mockTargetId, role: MemberRole.MEMBER, leftAt: null } as any);

      await expect(service.removeMember(mockConvId, mockUserId, mockTargetId)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });
});

-- Thêm cột hidden_by_users dưới dạng mảng UUID để hỗ trợ tính năng "Xóa chỉ ở máy tôi"
ALTER TABLE message ADD COLUMN hidden_by_users UUID[] DEFAULT '{}'::UUID[] NOT NULL;

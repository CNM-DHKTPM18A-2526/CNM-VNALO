import { useState } from 'react'
import { Icon } from '../shared/components/Icon'
import { useLanguage } from '../shared/i18n/LanguageContext'

type DocCategory = 'all' | 'images' | 'videos' | 'files' | 'links'

interface MockDocument {
  id: string
  name: string
  type: DocCategory
  size?: string
  date: string
  sender: string
  conversation: string
  url?: string
}

const mockDocs: MockDocument[] = [
  { id: '1', name: 'Báo cáo dự án.pdf', type: 'files', size: '2.4 MB', date: '2026-04-12', sender: 'Nguyễn Văn A', conversation: 'Nhóm Công việc' },
  { id: '2', name: 'Thiết kế UI.png', type: 'images', size: '1.2 MB', date: '2026-04-11', sender: 'Trần Thị B', conversation: 'Nhóm Thiết kế' },
  { id: '3', name: 'https://zalo.me/g/vnalo', type: 'links', date: '2026-04-10', sender: 'Lê Văn C', conversation: 'Nhóm Bạn thân' },
  { id: '4', name: 'Video giới thiệu.mp4', type: 'videos', size: '15 MB', date: '2026-04-09', sender: 'Phạm Văn D', conversation: 'Nhóm Marketing' },
]

export function DocumentsPage() {
  const { t } = useLanguage()
  const [activeTab, setActiveTab] = useState<DocCategory>('all')

  const filteredDocs = activeTab === 'all' ? mockDocs : mockDocs.filter(d => d.type === activeTab)

  return (
    <div className="documents-page">
      <header className="documents-header">
        <div className="header-title">
          <Icon name="folder" className="title-icon" />
          <h1>{t('documents.title') || 'Quản lý file'}</h1>
        </div>
        <div className="header-search">
          <div className="search-box">
            <Icon name="search" className="search-icon" />
            <input type="text" placeholder={t('documents.search_placeholder') || 'Tìm kiếm tài liệu...'} />
          </div>
        </div>
      </header>

      <nav className="documents-tabs">
        <button 
          className={activeTab === 'all' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('all')}
        >
          {t('documents.tab_all') || 'Tất cả'}
        </button>
        <button 
          className={activeTab === 'images' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('images')}
        >
          {t('documents.tab_images') || 'Hình ảnh'}
        </button>
        <button 
          className={activeTab === 'videos' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('videos')}
        >
          {t('documents.tab_videos') || 'Video'}
        </button>
        <button 
          className={activeTab === 'files' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('files')}
        >
          {t('documents.tab_files') || 'Tài liệu'}
        </button>
        <button 
          className={activeTab === 'links' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('links')}
        >
          {t('documents.tab_links') || 'Liên kết'}
        </button>
      </nav>

      <div className="documents-content">
        {filteredDocs.length > 0 ? (
          <table className="docs-table">
            <thead>
              <tr>
                <th>{t('documents.col_name') || 'Tên tài liệu'}</th>
                <th>{t('documents.col_sender') || 'Người gửi'}</th>
                <th>{t('documents.col_conversation') || 'Hội thoại'}</th>
                <th>{t('documents.col_date') || 'Ngày gửi'}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {filteredDocs.map(doc => (
                <tr key={doc.id}>
                  <td>
                    <div className="doc-name-cell">
                      <div className={`doc-icon-wrapper ${doc.type}`}>
                        <Icon name={doc.type === 'images' ? 'image' : doc.type === 'links' ? 'spark' : 'file'} />
                      </div>
                      <div className="doc-info">
                        <span className="doc-name">{doc.name}</span>
                        {doc.size && <span className="doc-size">{doc.size}</span>}
                      </div>
                    </div>
                  </td>
                  <td>{doc.sender}</td>
                  <td>{doc.conversation}</td>
                  <td>{doc.date}</td>
                  <td className="actions-cell">
                    <button className="action-btn" title="Tải xuống">
                      <Icon name="attach" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <div className="empty-state">
            <div className="empty-icon">
              <Icon name="folder" />
            </div>
            <p>{t('documents.empty') || 'Không tìm thấy tài liệu nào'}</p>
          </div>
        )}
      </div>

      <style>{`
        .documents-page {
          display: flex;
          flex-direction: column;
          height: 100%;
          background: #fff;
          color: #333;
        }

        .documents-header {
          padding: 24px 32px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          border-bottom: 1px solid #efefef;
        }

        .header-title {
          display: flex;
          align-items: center;
          gap: 12px;
        }

        .title-icon {
          width: 32px;
          height: 32px;
          color: #005ae0;
        }

        .header-title h1 {
          font-size: 24px;
          font-weight: 600;
          color: #1a1a1a;
        }

        .search-box {
          display: flex;
          align-items: center;
          gap: 10px;
          background: #f1f3f5;
          padding: 10px 16px;
          border-radius: 999px;
          min-width: 300px;
        }

        .search-icon {
          width: 18px;
          height: 18px;
          color: #adb5bd;
        }

        .search-box input {
          background: transparent;
          border: none;
          outline: none;
          width: 100%;
          font-size: 14px;
        }

        .documents-tabs {
          padding: 0 32px;
          display: flex;
          gap: 32px;
          border-bottom: 1px solid #efefef;
        }

        .tab-item {
          padding: 16px 0;
          background: transparent;
          border: none;
          border-bottom: 3px solid transparent;
          color: #666;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.2s;
        }

        .tab-item:hover {
          color: #005ae0;
        }

        .tab-item.active {
          color: #005ae0;
          border-bottom-color: #005ae0;
        }

        .documents-content {
          flex: 1;
          padding: 0;
          overflow-y: auto;
        }

        .docs-table {
          width: 100%;
          border-collapse: collapse;
        }

        .docs-table th {
          text-align: left;
          padding: 16px 32px;
          font-size: 13px;
          color: #999;
          font-weight: 500;
          border-bottom: 1px solid #f8f9fa;
        }

        .docs-table td {
          padding: 12px 32px;
          border-bottom: 1px solid #f8f9fa;
          font-size: 14px;
        }

        .docs-table tr:hover {
          background: #f8f9fb;
        }

        .doc-name-cell {
          display: flex;
          align-items: center;
          gap: 16px;
        }

        .doc-icon-wrapper {
          width: 40px;
          height: 40px;
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .doc-icon-wrapper.files { background: #e7f3ff; color: #0056b3; }
        .doc-icon-wrapper.images { background: #fff0f6; color: #d6336c; }
        .doc-icon-wrapper.videos { background: #f3f0ff; color: #6741d9; }
        .doc-icon-wrapper.links { background: #fff9db; color: #f08c00; }

        .doc-info {
          display: flex;
          flex-direction: column;
        }

        .doc-name {
          font-weight: 500;
          color: #1a1a1a;
          word-break: break-all;
        }

        .doc-size {
          font-size: 11px;
          color: #999;
          margin-top: 2px;
        }

        .action-btn {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          border: none;
          background: transparent;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #adb5bd;
          cursor: pointer;
        }

        .action-btn:hover {
          background: #e9ecef;
          color: #1a1a1a;
        }

        .empty-state {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 100px 0;
          color: #adb5bd;
        }

        .empty-icon {
          width: 64px;
          height: 64px;
          margin-bottom: 16px;
          opacity: 0.2;
        }
      `}</style>
    </div>
  )
}

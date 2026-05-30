import React from 'react'
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
  const [activeTab, setActiveTab] = React.useState<DocCategory>('all')

  const filteredDocs = activeTab === 'all' ? mockDocs : mockDocs.filter(d => d.type === activeTab)

  return (
    <div className="documents-page">
      <header className="documents-header">
        <div className="header-title">
          <Icon name="folder" className="title-icon" />
          <h1>{t('pages.documents.title') || 'Quản lý file'}</h1>
        </div>
        <div className="header-search">
          <div className="search-box">
            <Icon name="search" className="search-icon" />
            <input type="text" placeholder={t('pages.documents.search_placeholder') || 'Tìm kiếm tài liệu...'} />
          </div>
        </div>
      </header>

      <nav className="documents-tabs">
        <button 
          className={activeTab === 'all' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('all')}
        >
          {t('pages.documents.tab_all') || 'Tất cả'}
        </button>
        <button 
          className={activeTab === 'images' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('images')}
        >
          {t('pages.documents.tab_images') || 'Hình ảnh'}
        </button>
        <button 
          className={activeTab === 'videos' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('videos')}
        >
          {t('pages.documents.tab_videos') || 'Video'}
        </button>
        <button 
          className={activeTab === 'files' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('files')}
        >
          {t('pages.documents.tab_files') || 'Tài liệu'}
        </button>
        <button 
          className={activeTab === 'links' ? 'tab-item active' : 'tab-item'} 
          onClick={() => setActiveTab('links')}
        >
          {t('pages.documents.tab_links') || 'Liên kết'}
        </button>
      </nav>

      <div className="documents-content">
        {filteredDocs.length > 0 ? (
          <table className="docs-table">
            <thead>
              <tr>
                <th>{t('pages.documents.col_name') || 'Tên tài liệu'}</th>
                <th>{t('pages.documents.col_sender') || 'Người gửi'}</th>
                <th>{t('pages.documents.col_conversation') || 'Hội thoại'}</th>
                <th>{t('pages.documents.col_date') || 'Ngày gửi'}</th>
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
            <p>{t('pages.documents.empty') || 'Không tìm thấy tài liệu nào'}</p>
          </div>
        )}
      </div>

      <style>{`
        .documents-page {
          display: flex;
          flex-direction: column;
          height: 100%;
          background: var(--surface);
          color: var(--text);
        }

        .documents-header {
          padding: 24px 32px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          border-bottom: 1px solid var(--border);
          background: var(--surface);
        }

        .header-title {
          display: flex;
          align-items: center;
          gap: 12px;
        }

        .title-icon {
          width: 32px;
          height: 32px;
          color: var(--primary);
        }

        .header-title h1 {
          font-size: 24px;
          font-weight: 600;
          color: var(--title-subtle);
        }

        .search-box {
          display: flex;
          align-items: center;
          gap: 10px;
          background: var(--bg);
          padding: 10px 16px;
          border-radius: 999px;
          min-width: 300px;
          border: 1px solid var(--border);
        }

        .search-icon {
          width: 18px;
          height: 18px;
          color: var(--muted);
        }

        .search-box input {
          background: transparent;
          border: none;
          outline: none;
          width: 100%;
          font-size: 14px;
          color: var(--text);
        }

        .documents-tabs {
          padding: 0 32px;
          display: flex;
          gap: 32px;
          border-bottom: 1px solid var(--border);
          background: var(--surface);
        }

        .tab-item {
          padding: 16px 0;
          background: transparent;
          border: none;
          border-bottom: 3px solid transparent;
          color: var(--muted);
          font-weight: 500;
          cursor: pointer;
          transition: all 0.2s;
        }

        .tab-item:hover {
          color: var(--primary);
        }

        .tab-item.active {
          color: var(--primary);
          border-bottom-color: var(--primary);
        }

        .documents-content {
          flex: 1;
          padding: 0;
          overflow-y: auto;
          background: var(--bg);
        }

        .docs-table {
          width: 100%;
          border-collapse: collapse;
        }

        .docs-table th {
          text-align: left;
          padding: 16px 32px;
          font-size: 13px;
          color: var(--muted);
          font-weight: 500;
          border-bottom: 1px solid var(--border);
          background: var(--surface);
        }

        .docs-table td {
          padding: 12px 32px;
          border-bottom: 1px solid var(--border);
          font-size: 14px;
          color: var(--text);
        }

        .docs-table tr {
          background: var(--surface);
        }

        .docs-table tr:hover {
          background: var(--surface-hover);
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

        .doc-icon-wrapper.files { 
          background: color-mix(in srgb, var(--primary) 12%, transparent); 
          color: var(--primary); 
        }
        .doc-icon-wrapper.images { 
          background: color-mix(in srgb, #d6336c 12%, transparent); 
          color: #d6336c; 
        }
        .doc-icon-wrapper.videos { 
          background: color-mix(in srgb, #6741d9 12%, transparent); 
          color: #6741d9; 
        }
        .doc-icon-wrapper.links { 
          background: color-mix(in srgb, #f08c00 12%, transparent); 
          color: #f08c00; 
        }

        .doc-info {
          display: flex;
          flex-direction: column;
        }

        .doc-name {
          font-weight: 500;
          color: var(--title-subtle);
          word-break: break-all;
        }

        .doc-size {
          font-size: 11px;
          color: var(--muted);
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
          color: var(--muted);
          cursor: pointer;
        }

        .action-btn:hover {
          background: var(--panel-highlight);
          color: var(--primary);
        }

        .empty-state {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 100px 0;
          color: var(--muted);
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

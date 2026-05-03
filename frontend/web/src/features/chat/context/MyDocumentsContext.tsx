import { createContext, useContext, useState, type ReactNode } from 'react'

interface MyDocumentsContextType {
  isOpen: boolean
  openMyDocuments: () => void
  closeMyDocuments: () => void
}

const MyDocumentsContext = createContext<MyDocumentsContextType | undefined>(undefined)

export function MyDocumentsProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false)

  const openMyDocuments = () => setIsOpen(true)
  const closeMyDocuments = () => setIsOpen(false)

  return (
    <MyDocumentsContext.Provider value={{ isOpen, openMyDocuments, closeMyDocuments }}>
      {children}
    </MyDocumentsContext.Provider>
  )
}

export function useMyDocuments() {
  const context = useContext(MyDocumentsContext)
  if (!context) {
    throw new Error('useMyDocuments must be used within MyDocumentsProvider')
  }
  return context
}

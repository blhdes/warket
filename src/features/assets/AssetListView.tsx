import { useCallback, useEffect, useMemo, useState } from 'react'
import { createPortal } from 'react-dom'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { Asset, VaultList } from '../../lib/types'
import {
  DndContext,
  DragOverlay,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  closestCenter,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core'
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import AssetCard from './AssetCard'
import AddAssetModal from './AddAssetModal'
import { Skeleton } from '../../components/Skeleton'
import { toast } from '../../components/Toast'
import { updatePositions } from '../../lib/position'
import { fetchAssetsForList } from '../../lib/queries'

interface Props {
  list: VaultList
  db: SupabaseClient
  onBack: () => void
  onEdit?: () => void
  readOnly?: boolean
}

export default function AssetListView({ list, db, onBack, onEdit, readOnly }: Props) {
  const [assets, setAssets] = useState<Asset[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [activeTag, setActiveTag] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [activeDragId, setActiveDragId] = useState<string | null>(null)
  const [expandedCount, setExpandedCount] = useState(0)

  /* ── DnD sensors ──────────────────────────────────────── */
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 400, tolerance: 8 } }),
  )

  /* ── Fetch ─────────────────────────────────────────────── */
  const fetchAssets = useCallback(async () => {
    const { data, error } = await fetchAssetsForList(db, list.id)

    if (error) {
      toast(error.message)
      setLoading(false)
      return
    }

    setAssets(data as Asset[])
    setLoading(false)
  }, [db, list.id])

  useEffect(() => { fetchAssets() }, [fetchAssets])

  /* ── Derived ───────────────────────────────────────────── */
  const allTags = useMemo(() => {
    const set = new Set<string>()
    assets.forEach(a => a.tags?.forEach(t => set.add(t)))
    return Array.from(set).sort()
  }, [assets])

  const isFiltered = Boolean(search || activeTag)
  const isDragDisabled = isFiltered || expandedCount > 0 || Boolean(readOnly)

  const filtered = useMemo(() => {
    let result = assets
    if (search) {
      const q = search.toLowerCase()
      result = result.filter(a =>
        a.name.toLowerCase().includes(q) || a.ticker.toLowerCase().includes(q)
      )
    }
    if (activeTag) {
      result = result.filter(a => a.tags?.includes(activeTag))
    }
    return result
  }, [assets, search, activeTag])

  /* ── Optimistic callbacks ──────────────────────────────── */
  const handleUpdate = (updated: Asset) => {
    setAssets(prev => prev.map(a => a.id === updated.id ? updated : a))
  }

  const handleDelete = (id: string) => {
    setAssets(prev => prev.filter(a => a.id !== id))
  }

  const handleCreated = (asset: Asset) => {
    setAssets(prev => [asset, ...prev])
  }

  /* ── DnD handlers ──────────────────────────────────────── */
  const handleDragStart = (event: DragStartEvent) => {
    setActiveDragId(event.active.id as string)
  }

  const handleDragEnd = async (event: DragEndEvent) => {
    setActiveDragId(null)
    const { active, over } = event
    if (!over || active.id === over.id) return

    const oldIndex = assets.findIndex(a => a.id === active.id)
    const newIndex = assets.findIndex(a => a.id === over.id)
    if (oldIndex === -1 || newIndex === -1) return

    const reordered = arrayMove(assets, oldIndex, newIndex)
    setAssets(reordered)

    const updates = reordered.map((a, i) => ({ id: a.id, position: i }))
    await updatePositions(db, 'assets', updates)
  }

  const draggedAsset = activeDragId ? assets.find(a => a.id === activeDragId) : null

  /* ── Render ────────────────────────────────────────────── */
  return (
    <div className="space-y-5 animate-fade-in">
      {/* Header */}
      <div className="flex flex-wrap items-center gap-3">
        <button
          onClick={onBack}
          className="btn-ghost flex items-center gap-1"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
            <path fillRule="evenodd" d="M17 10a.75.75 0 0 1-.75.75H5.612l4.158 3.96a.75.75 0 1 1-1.04 1.08l-5.5-5.25a.75.75 0 0 1 0-1.08l5.5-5.25a.75.75 0 1 1 1.04 1.08L5.612 9.25H16.25A.75.75 0 0 1 17 10Z" clipRule="evenodd" />
          </svg>
          Back
        </button>
        <div className="flex-1 min-w-0">
          <h2
            className="truncate"
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: '1.25rem',
              color: 'var(--text-primary)',
            }}
          >
            {list.name}
          </h2>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            {assets.length} {assets.length === 1 ? 'asset' : 'assets'}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {onEdit && (
            <button
              onClick={onEdit}
              className="btn-ghost flex items-center gap-1"
              title="Edit list"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
                <path d="m5.433 13.917 1.262-3.155A4 4 0 0 1 7.58 9.42l6.92-6.918a2.121 2.121 0 0 1 3 3l-6.92 6.918c-.383.383-.84.685-1.343.886l-3.154 1.262a.5.5 0 0 1-.65-.65Z" />
                <path d="M3.5 5.75c0-.69.56-1.25 1.25-1.25h5.5a.75.75 0 0 0 0-1.5h-5.5A2.75 2.75 0 0 0 2 5.75v8.5A2.75 2.75 0 0 0 4.75 17h8.5A2.75 2.75 0 0 0 16 14.25v-5.5a.75.75 0 0 0-1.5 0v5.5c0 .69-.56 1.25-1.25 1.25h-8.5c-.69 0-1.25-.56-1.25-1.25v-8.5Z" />
              </svg>
              <span className="hidden sm:inline" style={{ fontSize: '0.8125rem' }}>Edit</span>
            </button>
          )}
          {!readOnly && (
            <button
              onClick={() => setModalOpen(true)}
              className="btn-primary shrink-0"
            >
              + Add Asset
            </button>
          )}
        </div>
      </div>

      {/* Search */}
      <input
        type="text"
        value={search}
        onChange={e => setSearch(e.target.value)}
        placeholder="Search by name or ticker..."
        className="input-field w-full sm:max-w-[288px]"
      />

      {/* Tag pills */}
      {allTags.length > 0 && (
        <div
          className="flex flex-nowrap gap-2 overflow-x-auto pb-1"
          style={{ scrollbarWidth: 'none' }}
        >
          {activeTag && (
            <button
              onClick={() => setActiveTag(null)}
              className="tag-pill btn-ghost"
              style={{ borderRadius: 'var(--radius-pill)' }}
            >
              Clear
            </button>
          )}
          {allTags.map(tag => (
            <button
              key={tag}
              onClick={() => setActiveTag(prev => (prev === tag ? null : tag))}
              className={`tag-pill ${
                activeTag === tag
                  ? 'tag-pill-active'
                  : 'tag-pill-default'
              }`}
            >
              {tag}
            </button>
          ))}
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      )}

      {/* Empty state */}
      {!loading && filtered.length === 0 && (
        <div
          className="flex flex-col items-center py-20 text-center"
          style={{
            border: '1px dashed var(--border-default)',
            borderRadius: 'var(--radius-lg)',
          }}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={1.5}
            stroke="currentColor"
            className="mb-3"
            width={24}
            height={24}
            style={{ color: 'var(--text-muted)' }}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z"
            />
          </svg>
          <p style={{ color: 'var(--text-tertiary)' }} className="text-sm">
            {assets.length === 0
              ? 'No assets in this list yet.'
              : 'No assets match your search.'}
          </p>
          {assets.length === 0 && !readOnly && (
            <button
              onClick={() => setModalOpen(true)}
              className="btn-primary mt-4"
            >
              + Add Asset
            </button>
          )}
        </div>
      )}

      {/* Asset cards with DnD */}
      {!loading && filtered.length > 0 && (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={filtered.map(a => a.id)}
            strategy={verticalListSortingStrategy}
            disabled={isDragDisabled}
          >
            <div className={`space-y-3 sm:space-y-2 ${activeDragId ? 'is-dragging' : ''}`}>
              {filtered.map(asset => (
                <SortableAssetWrapper
                  key={asset.id}
                  asset={asset}
                  db={db}
                  onUpdate={handleUpdate}
                  onDelete={handleDelete}
                  isDragDisabled={isDragDisabled}
                  onExpandChange={exp => setExpandedCount(c => c + (exp ? 1 : -1))}
                  readOnly={readOnly}
                />
              ))}
            </div>
          </SortableContext>
          {createPortal(
            <DragOverlay dropAnimation={{ duration: 200, easing: 'ease' }}>
              {draggedAsset ? (
                <div
                  className="drag-overlay"
                  style={{
                    background: 'var(--surface-1)',
                    padding: '12px 16px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                  }}
                >
                  <span
                    style={{
                      fontFamily: 'var(--font-mono)',
                      fontSize: '0.6875rem',
                      fontWeight: 700,
                      color: 'var(--text-primary)',
                      textTransform: 'uppercase',
                    }}
                  >
                    {draggedAsset.ticker}
                  </span>
                  <span style={{ fontSize: '0.875rem', color: 'var(--text-primary)' }}>
                    {draggedAsset.name}
                  </span>
                </div>
              ) : null}
            </DragOverlay>,
            document.body,
          )}
        </DndContext>
      )}

      {/* Add modal */}
      {!readOnly && (
        <AddAssetModal
          open={modalOpen}
          onClose={() => setModalOpen(false)}
          db={db}
          listId={list.id}
          onCreated={handleCreated}
        />
      )}
    </div>
  )
}

/* ── Sortable wrapper for AssetCard ──────────────────────── */

function SortableAssetWrapper({
  asset,
  db,
  onUpdate,
  onDelete,
  isDragDisabled,
  onExpandChange,
  readOnly,
}: {
  asset: Asset
  db: SupabaseClient
  onUpdate: (updated: Asset) => void
  onDelete: (id: string) => void
  isDragDisabled: boolean
  onExpandChange: (expanded: boolean) => void
  readOnly?: boolean
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: asset.id, disabled: isDragDisabled })

  const style: React.CSSProperties = {
    transform: CSS.Translate.toString(transform),
    transition,
    opacity: isDragging ? 0.35 : 1,
    ...(isDragDisabled ? {} : { WebkitTouchCallout: 'none', userSelect: 'none', touchAction: 'none' }),
  }

  const dragProps = isDragDisabled ? {} : { ...attributes, ...listeners }

  return (
    <div ref={setNodeRef} style={style} {...dragProps}>
      <AssetCard
        asset={asset}
        db={db}
        onUpdate={onUpdate}
        onDelete={onDelete}
        showDragHandle={!isDragDisabled}
        onExpandChange={onExpandChange}
        readOnly={readOnly}
      />
    </div>
  )
}

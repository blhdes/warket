import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { VaultList } from '../../lib/types'
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
  rectSortingStrategy,
  useSortable,
  arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import Modal from '../../components/Modal'
import { ListCardSkeleton } from '../../components/Skeleton'
import { toast } from '../../components/Toast'
import { updatePositions } from '../../lib/position'
import { haptic } from '../../lib/haptics'
import AssetListView from '../assets/AssetListView'
import { useFormNavigation } from '../../hooks/useFormNavigation'

type ListWithCount = VaultList & { asset_count: number }

interface Props {
  db: SupabaseClient
  vaultHash: string
  readOnly?: boolean
}

export default function ListsView({ db, vaultHash, readOnly }: Props) {
  const [lists, setLists] = useState<ListWithCount[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [activeTag, setActiveTag] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [selectedList, setSelectedList] = useState<VaultList | null>(null)
  const [viewDirection, setViewDirection] = useState<'forward' | 'back'>('forward')
  const [editingList, setEditingList] = useState<ListWithCount | null>(null)
  const [activeDragId, setActiveDragId] = useState<string | null>(null)

  /* ── DnD sensors ──────────────────────────────────────── */
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 400, tolerance: 8 } }),
  )

  /* ── Asset search index (lightweight: name + ticker per list) */
  const [assetIndex, setAssetIndex] = useState<Map<string, { name: string; ticker: string }[]>>(new Map())

  /* ── Fetch ─────────────────────────────────────────────── */
  const fetchLists = useCallback(async () => {
    const listRes = await db
      .from('lists')
      .select('*, assets(count)')
      .eq('vault_hash', vaultHash)
      .order('position', { ascending: true })

    if (listRes.error) {
      toast(listRes.error.message)
      setLoading(false)
      return
    }

    const mapped = (listRes.data ?? []).map((row: any) => ({
      ...row,
      asset_count: row.assets?.[0]?.count ?? 0,
    }))

    setLists(mapped)
    setLoading(false)

    // Fetch lightweight asset index for search (non-blocking)
    const listIds = mapped.map((l: any) => l.id)
    if (listIds.length > 0) {
      const assetRes = await db
        .from('assets')
        .select('list_id, name, ticker')
        .in('list_id', listIds)

      const idx = new Map<string, { name: string; ticker: string }[]>()
      for (const a of (assetRes.data ?? []) as { list_id: string; name: string; ticker: string }[]) {
        const arr = idx.get(a.list_id) ?? []
        arr.push({ name: a.name, ticker: a.ticker })
        idx.set(a.list_id, arr)
      }
      setAssetIndex(idx)
    }
  }, [db, vaultHash])

  useEffect(() => { fetchLists() }, [fetchLists])

  /* ── Derived ───────────────────────────────────────────── */
  const allTags = useMemo(() => {
    const set = new Set<string>()
    lists.forEach(l => l.tags?.forEach(t => set.add(t)))
    return Array.from(set).sort()
  }, [lists])

  const isFiltered = Boolean(search || activeTag || readOnly)

  const filtered = useMemo(() => {
    let result = lists
    if (search) {
      const q = search.toLowerCase()
      result = result.filter(l => {
        if (l.name.toLowerCase().includes(q)) return true
        const assets = assetIndex.get(l.id) ?? []
        return assets.some(a => a.name.toLowerCase().includes(q) || a.ticker.toLowerCase().includes(q))
      })
    }
    if (activeTag) {
      result = result.filter(l => l.tags?.includes(activeTag))
    }
    return result
  }, [lists, search, activeTag, assetIndex])

  /* ── Create ────────────────────────────────────────────── */
  const handleCreate = async (name: string, tags: string[]) => {
    const position = lists.length
    const { error } = await db
      .from('lists')
      .insert({ vault_hash: vaultHash, name, tags, position })

    if (error) {
      toast(error.message)
      return
    }

    toast('List created', 'success')
    setModalOpen(false)
    fetchLists()
  }

  /* ── Update ────────────────────────────────────────────── */
  const handleUpdateList = async (updated: ListWithCount) => {
    const { error } = await db
      .from('lists')
      .update({ name: updated.name, tags: updated.tags })
      .eq('id', updated.id)

    if (error) {
      toast(error.message)
      return
    }

    toast('List updated', 'success')
    setLists(prev => prev.map(l => l.id === updated.id ? updated : l))
    // Also update selectedList if we're editing from inside AssetListView
    if (selectedList?.id === updated.id) {
      setSelectedList(updated)
    }
    setEditingList(null)
  }

  /* ── Delete ────────────────────────────────────────────── */
  const handleDelete = async (id: string) => {
    const { error } = await db.from('lists').delete().eq('id', id)

    if (error) {
      toast(error.message)
      return
    }

    toast('List deleted', 'success')
    setLists(prev => prev.filter(l => l.id !== id))
    setEditingList(null)
    // If we deleted the list we're viewing, go back
    if (selectedList?.id === id) {
      setViewDirection('back')
      setSelectedList(null)
    }
  }

  /* ── DnD handlers ──────────────────────────────────────── */
  const handleDragStart = (event: DragStartEvent) => {
    setActiveDragId(event.active.id as string)
  }

  const handleDragEnd = async (event: DragEndEvent) => {
    setActiveDragId(null)
    const { active, over } = event
    if (!over || active.id === over.id) return
    haptic.light()

    const oldIndex = lists.findIndex(l => l.id === active.id)
    const newIndex = lists.findIndex(l => l.id === over.id)
    if (oldIndex === -1 || newIndex === -1) return

    const reordered = arrayMove(lists, oldIndex, newIndex)
    setLists(reordered)

    // Persist new positions
    const updates = reordered.map((l, i) => ({ id: l.id, position: i }))
    await updatePositions(db, 'lists', updates)
  }

  const draggedList = activeDragId ? lists.find(l => l.id === activeDragId) : null

  /* ── Render ────────────────────────────────────────────── */

  if (selectedList) {
    return (
      <div className={viewDirection === 'forward' ? 'animate-view-enter' : 'animate-view-enter-back'}>
        <AssetListView
          list={selectedList}
          db={db}
          onBack={() => { setViewDirection('back'); setSelectedList(null); fetchLists() }}
          onEdit={readOnly ? undefined : () => {
            const full = lists.find(l => l.id === selectedList.id)
            if (full) setEditingList(full)
          }}
          readOnly={readOnly}
        />
        {!readOnly && (
          <EditListModal
            open={editingList !== null && selectedList !== null}
            onClose={() => setEditingList(null)}
            list={editingList}
            onSave={handleUpdateList}
            onDelete={handleDelete}
          />
        )}
      </div>
    )
  }

  return (
    <div className={`space-y-5 ${viewDirection === 'back' ? 'animate-view-enter-back' : 'animate-fade-in'}`}>
      {/* Toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <input
          type="text"
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search lists, assets, tickers..."
          className="input-field w-full sm:max-w-[256px]"
        />
        {!readOnly && (
          <button
            onClick={() => setModalOpen(true)}
            className="btn-primary shrink-0"
          >
            + New List
          </button>
        )}
      </div>

      {/* Tag pills */}
      {allTags.length > 0 && (
        <div className="flex flex-wrap gap-2">
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
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <ListCardSkeleton key={i} />
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
              d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z"
            />
          </svg>
          <p style={{ color: 'var(--text-tertiary)' }} className="text-sm">
            {lists.length === 0
              ? (readOnly ? 'This vault has no lists.' : 'No lists yet. Create your first one.')
              : 'No lists match your search.'}
          </p>
          {lists.length === 0 && !readOnly && (
            <button
              onClick={() => setModalOpen(true)}
              className="btn-primary mt-4"
            >
              + New List
            </button>
          )}
        </div>
      )}

      {/* List cards with DnD */}
      {!loading && filtered.length > 0 && (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={filtered.map(l => l.id)}
            strategy={rectSortingStrategy}
            disabled={isFiltered}
          >
            <div className={`grid gap-5 sm:gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 ${activeDragId ? 'is-dragging' : ''}`}>
              {filtered.map(list => (
                <SortableListCard
                  key={list.id}
                  list={list}
                  onSelect={() => { setViewDirection('forward'); setSelectedList(list) }}
                  onEdit={() => setEditingList(list)}
                  isDragDisabled={isFiltered}
                  readOnly={readOnly}
                />
              ))}
            </div>
          </SortableContext>
          {createPortal(
            <DragOverlay dropAnimation={{ duration: 200, easing: 'ease' }}>
              {draggedList ? (
                <div className="drag-overlay" style={{ background: 'var(--surface-1)' }}>
                  <ListCardContent list={draggedList} />
                </div>
              ) : null}
            </DragOverlay>,
            document.body,
          )}
        </DndContext>
      )}

      {/* Create modal */}
      {!readOnly && (
        <>
          <CreateListModal
            open={modalOpen}
            onClose={() => setModalOpen(false)}
            onCreate={handleCreate}
          />
          <EditListModal
            open={editingList !== null && selectedList === null}
            onClose={() => setEditingList(null)}
            list={editingList}
            onSave={handleUpdateList}
            onDelete={handleDelete}
          />
        </>
      )}
    </div>
  )
}

/* ── 6-dot grip icon ─────────────────────────────────────── */

function GripIcon({ className }: { className?: string }) {
  return (
    <svg width="10" height="16" viewBox="0 0 10 16" fill="currentColor" className={className}>
      <circle cx="2" cy="2" r="1.5" />
      <circle cx="8" cy="2" r="1.5" />
      <circle cx="2" cy="8" r="1.5" />
      <circle cx="8" cy="8" r="1.5" />
      <circle cx="2" cy="14" r="1.5" />
      <circle cx="8" cy="14" r="1.5" />
    </svg>
  )
}

/* ── List card content (shared between sortable + overlay) ── */

function ListCardContent({ list }: { list: ListWithCount }) {
  return (
    <div className="pt-5 pb-5 pr-5 pl-4 sm:pl-7">
      <h3
        className="pr-6"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: '1.125rem',
          color: 'var(--text-primary)',
        }}
      >
        {list.name}
      </h3>

      {list.tags && list.tags.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {list.tags.map(tag => (
            <span key={tag} className="tag-display">
              {tag}
            </span>
          ))}
        </div>
      )}

      {list.asset_count > 0 && (
        <p
          className="mt-3"
          style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}
        >
          {list.asset_count} {list.asset_count === 1 ? 'asset' : 'assets'}
        </p>
      )}
    </div>
  )
}

/* ── Sortable list card ──────────────────────────────────── */

function SortableListCard({
  list,
  onSelect,
  onEdit,
  isDragDisabled,
  readOnly,
}: {
  list: ListWithCount
  onSelect: () => void
  onEdit: () => void
  isDragDisabled: boolean
  readOnly?: boolean
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: list.id, disabled: isDragDisabled })

  const style: React.CSSProperties = {
    transform: CSS.Translate.toString(transform),
    transition,
    opacity: isDragging ? 0.35 : 1,
    ...(isDragDisabled ? {} : { WebkitTouchCallout: 'none', userSelect: 'none', touchAction: 'none' }),
  }

  const dragProps = isDragDisabled ? {} : { ...attributes, ...listeners }

  return (
    <div
      ref={setNodeRef}
      style={style}
      onClick={onSelect}
      className="card-surface group relative cursor-pointer"
      {...dragProps}
    >
      {/* Drag handle — visual indicator only (desktop); listeners are on the card */}
      {!isDragDisabled && (
        <div
          className="drag-handle absolute left-1 top-1/2 -translate-y-1/2 p-1 opacity-0 transition-opacity group-hover:opacity-100 hidden sm:flex"
        >
          <GripIcon />
        </div>
      )}

      {/* Edit button */}
      {!readOnly && (
        <button
          onClick={e => {
            e.stopPropagation()
            onEdit()
          }}
          className="absolute right-3 top-3 rounded p-1 opacity-0 transition-all group-hover:opacity-100"
          style={{ color: 'var(--text-muted)' }}
          onMouseEnter={e => { (e.currentTarget as HTMLElement).style.color = 'var(--text-primary)' }}
          onMouseLeave={e => { (e.currentTarget as HTMLElement).style.color = 'var(--text-muted)' }}
          title="Edit list"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
            <path d="m5.433 13.917 1.262-3.155A4 4 0 0 1 7.58 9.42l6.92-6.918a2.121 2.121 0 0 1 3 3l-6.92 6.918c-.383.383-.84.685-1.343.886l-3.154 1.262a.5.5 0 0 1-.65-.65Z" />
            <path d="M3.5 5.75c0-.69.56-1.25 1.25-1.25h5.5a.75.75 0 0 0 0-1.5h-5.5A2.75 2.75 0 0 0 2 5.75v8.5A2.75 2.75 0 0 0 4.75 17h8.5A2.75 2.75 0 0 0 16 14.25v-5.5a.75.75 0 0 0-1.5 0v5.5c0 .69-.56 1.25-1.25 1.25h-8.5c-.69 0-1.25-.56-1.25-1.25v-8.5Z" />
          </svg>
        </button>
      )}

      <ListCardContent list={list} />
    </div>
  )
}

/* ── Create List Modal ─────────────────────────────────── */

function CreateListModal({
  open,
  onClose,
  onCreate,
}: {
  open: boolean
  onClose: () => void
  onCreate: (name: string, tags: string[]) => Promise<void>
}) {
  const [name, setName] = useState('')
  const [tagsInput, setTagsInput] = useState('')
  const [saving, setSaving] = useState(false)
  const formRef = useRef<HTMLFormElement>(null)
  useFormNavigation(formRef)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return

    const tags = tagsInput
      .split(',')
      .map(t => t.trim().toLowerCase())
      .filter(Boolean)

    setSaving(true)
    await onCreate(name.trim(), tags)
    setSaving(false)
    setName('')
    setTagsInput('')
  }

  return (
    <Modal open={open} onClose={onClose} title="New List">
      <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <label className="label-sm block">
            Name
          </label>
          <input
            type="text"
            value={name}
            onChange={e => setName(e.target.value)}
            placeholder="e.g. AI Stocks"
            autoFocus
            className="input-field"
          />
        </div>

        <div className="space-y-1.5">
          <label className="label-sm block">
            Tags
          </label>
          <input
            type="text"
            value={tagsInput}
            onChange={e => setTagsInput(e.target.value)}
            placeholder="ai, tech, growth (comma-separated)"
            className="input-field"
          />
        </div>

        <button
          type="submit"
          disabled={!name.trim() || saving}
          className="btn-primary w-full"
        >
          {saving ? 'Creating...' : 'Create List'}
        </button>
      </form>
    </Modal>
  )
}

/* ── Edit List Modal ──────────────────────────────────── */

function EditListModal({
  open,
  onClose,
  list,
  onSave,
  onDelete,
}: {
  open: boolean
  onClose: () => void
  list: ListWithCount | null
  onSave: (updated: ListWithCount) => Promise<void>
  onDelete: (id: string) => Promise<void>
}) {
  const [name, setName] = useState('')
  const [tagsInput, setTagsInput] = useState('')
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const formRef = useRef<HTMLFormElement>(null)
  useFormNavigation(formRef)

  useEffect(() => {
    if (open && list) {
      setName(list.name)
      setTagsInput(list.tags?.join(', ') ?? '')
      setConfirmDelete(false)
    }
  }, [open, list])

  if (!list) return null

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return

    const tags = tagsInput
      .split(',')
      .map(t => t.trim().toLowerCase())
      .filter(Boolean)

    setSaving(true)
    await onSave({ ...list, name: name.trim(), tags })
    setSaving(false)
  }

  const handleDelete = async () => {
    setSaving(true)
    await onDelete(list.id)
    setSaving(false)
  }

  return (
    <Modal open={open} onClose={onClose} title="Edit List">
      <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <label className="label-sm block">Name</label>
          <input
            type="text"
            value={name}
            onChange={e => setName(e.target.value)}
            autoFocus
            className="input-field"
          />
        </div>

        <div className="space-y-1.5">
          <label className="label-sm block">Tags</label>
          <input
            type="text"
            value={tagsInput}
            onChange={e => setTagsInput(e.target.value)}
            placeholder="ai, tech, growth (comma-separated)"
            className="input-field"
          />
        </div>

        <button
          type="submit"
          disabled={!name.trim() || saving}
          className="btn-primary w-full"
        >
          {saving ? 'Saving...' : 'Save Changes'}
        </button>
      </form>

      {/* Delete section */}
      <div
        className="mt-5 pt-4"
        style={{ borderTop: '1px solid var(--border-default)' }}
      >
        {!confirmDelete ? (
          <button
            onClick={() => { haptic.warning(); setConfirmDelete(true) }}
            className="text-sm"
            style={{ color: 'var(--error)', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
          >
            Delete this list
          </button>
        ) : (
          <div className="space-y-2">
            <p style={{ fontSize: '0.8125rem', color: 'var(--error)' }}>
              This will delete the list and all {list.asset_count} {list.asset_count === 1 ? 'asset' : 'assets'} inside it. This cannot be undone.
            </p>
            <div className="flex gap-2">
              <button
                onClick={handleDelete}
                disabled={saving}
                className="btn-primary"
                style={{ backgroundColor: 'var(--error)', fontSize: '0.8125rem' }}
              >
                {saving ? 'Deleting...' : 'Confirm Delete'}
              </button>
              <button
                onClick={() => setConfirmDelete(false)}
                className="btn-ghost"
                style={{ fontSize: '0.8125rem' }}
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
    </Modal>
  )
}

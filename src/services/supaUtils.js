import { supabase } from '@/supabase'

export async function runRpc(name, params) {
  try {
    const { data, error } = await supabase.rpc(name, params)
    if (error) {
      throw new Error(`${error.code || 'RPC_ERROR'}: ${error.message}`)
    }
    return data
  } catch (e) {
    throw new Error(`RPC_FAILED: ${e.message}`)
  }
}

export function paginate(query, { limit = 20, offset = 0 }) {
  return query.range(offset, offset + limit - 1)
}

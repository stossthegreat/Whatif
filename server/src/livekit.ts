import { AccessToken } from 'livekit-server-sdk';

const KEY = process.env.LIVEKIT_API_KEY || '';
const SECRET = process.env.LIVEKIT_API_SECRET || '';
export const LIVEKIT_URL = process.env.LIVEKIT_URL || '';

/// Mints a per-member LiveKit room token. Empty string when keys aren't set
/// (matchmaking still works, video is simply disabled — fail-soft).
export async function mintToken(room: string, identity: string, name: string): Promise<string> {
  if (!KEY || !SECRET) return '';
  const at = new AccessToken(KEY, SECRET, { identity, name, ttl: '2h' });
  at.addGrant({ roomJoin: true, room, canPublish: true, canSubscribe: true });
  return await at.toJwt();
}

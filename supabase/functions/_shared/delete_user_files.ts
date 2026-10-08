// Decision record: docs/specs/_root/0013-seller-application-request/index.md
// (AC-11, build plan task 7)
//
// Removes every file one person uploaded for a seller application: the logo in
// `store-logos` and the ID and business photos in `application-documents`.
// Both buckets keep a person's files under a folder named with their id
// (`<id>/<name>` and `<id>/<application id>/<name>`), and clients can never
// delete them, so account deletion is the only thing that removes them.
//
// This walks the folders through the Storage API instead of reading a list of
// paths off the applications table, because a file can sit in storage with no
// application pointing at it (an upload that worked and a submit that did not,
// or a replaced photo). Deleting rows from `storage.objects` directly is
// refused by Storage, only its API removes the file as well.
//
// Kept apart from `delete_user_data.ts` and free of any Deno or npm import, so
// a test can run it against a fake Storage.

import { VISITOR_BUCKET } from "./claim_seller_application.ts";

/// The two buckets spec 0013 creates.
export const APPLICATION_BUCKETS = ["store-logos", "application-documents"];

type StorageResult<T> = {
  data: T | null;
  error: { message: string } | null;
};

/// What Storage's `list` returns for one entry. A folder has no `id`.
type StorageEntry = { name: string; id: string | null };

/// The slice of one bucket's Storage API this needs, so a test can stand in
/// for it. `supabase.storage.from(bucket)` fits.
export interface StorageBucket {
  list(
    path: string,
    options: { limit: number; offset: number },
  ): Promise<StorageResult<StorageEntry[]>>;
  remove(paths: string[]): Promise<StorageResult<unknown>>;
}

export interface StorageClient {
  from(bucket: string): StorageBucket;
}

const LIST_PAGE_SIZE = 100;
const REMOVE_CHUNK_SIZE = 100;

/// Every file path under `folder`, folders inside folders included.
async function listFiles(
  bucket: StorageBucket,
  folder: string,
  pageSize: number,
): Promise<string[]> {
  const files: string[] = [];
  const folders = [folder];
  while (folders.length > 0) {
    const current = folders.pop()!;
    for (let offset = 0;; offset += pageSize) {
      const { data, error } = await bucket.list(current, {
        limit: pageSize,
        offset,
      });
      if (error) throw new Error(error.message);
      const entries = data ?? [];
      for (const entry of entries) {
        const path = `${current}/${entry.name}`;
        // Storage gives a folder no `id`.
        (entry.id === null ? folders : files).push(path);
      }
      if (entries.length < pageSize) break;
    }
  }
  return files;
}

async function emptyFolder(
  bucket: StorageBucket,
  folder: string,
  pageSize: number,
): Promise<void> {
  const files = await listFiles(bucket, folder, pageSize);
  for (let i = 0; i < files.length; i += REMOVE_CHUNK_SIZE) {
    const { error } = await bucket.remove(files.slice(i, i + REMOVE_CHUNK_SIZE));
    if (error) throw new Error(error.message);
  }
}

/// Deletes everything `userId` uploaded to both application buckets.
///
/// Idempotent: a folder that is already empty or missing is not an error, so
/// a retried webhook or a second attempt after a partial failure is safe. A
/// failure in one bucket does not stop the other. Returns the first error, or
/// null when everything went. `pageSize` is only for tests.
export async function deleteUserFiles(
  storage: StorageClient,
  userId: string,
  pageSize = LIST_PAGE_SIZE,
): Promise<Error | null> {
  // The id is the folder name. An empty one, or one with a slash or a dot
  // segment, would list the bucket root or another person's folder, and
  // deleting that would be far worse than leaving a file behind.
  if (
    userId.length === 0 || userId.includes("/") || userId === "." ||
    userId === ".."
  ) {
    return new Error("invalid user id for storage cleanup");
  }

  let firstError: Error | null = null;
  for (const name of APPLICATION_BUCKETS) {
    try {
      await emptyFolder(storage.from(name), userId, pageSize);
    } catch (error) {
      firstError ??= error instanceof Error ? error : new Error(String(error));
    }
  }
  return firstError;
}

/// The slice of the `seller_applications` table the visitor cleanup needs, so a
/// test can stand in for it (the real one is in `delete_user_data.ts`).
export interface VisitorApplicationRows {
  /// The visitor applications `userId` owns: `applicant_id` equals the account,
  /// which includes claimed rows. With the file paths on them. Rows that are only
  /// attached (`bound_account_id`, no `applicant_id`) are somebody else's
  /// application and are not listed.
  list(userId: string): Promise<{ id: string; paths: (string | null)[] }[]>;
  /// Deletes those rows.
  remove(ids: string[]): Promise<void>;
  /// Sets `bound_account_id` to null on the rows that are only attached to
  /// `userId`, so the real applicant's row and photos survive until the retention
  /// job. A row whose detach would break the one open rule may stay attached.
  detach(userId: string): Promise<void>;
}

/// Removes the visitor applications `userId` owns and their files in
/// `visitor-documents`, and detaches the ones that are only attached to it
/// (spec 0014, AC-14). Those files sit in the folder of the anonymous session
/// that sent them, not in a folder named with `userId`, so the folder walk in
/// `deleteUserFiles` cannot find them: the paths come from the rows. A visitor row
/// has no cascade from the profile either, so the owned ones are deleted here.
///
/// Order matters and is on purpose: read the paths, remove the files, delete the
/// rows, and only then detach. A failure before the rows go leaves them (and their
/// paths) in place for a retry, and returns the error so the caller does not go
/// on to delete the profile, which would cascade away a claimed row and its
/// paths. Idempotent: nothing to delete or detach is not an error. Returns the
/// error, or null when everything went.
export async function deleteVisitorApplications(
  storage: StorageClient,
  rows: VisitorApplicationRows,
  userId: string,
): Promise<Error | null> {
  if (userId.length === 0) return new Error("invalid user id for cleanup");

  try {
    const applications = await rows.list(userId);
    if (applications.length > 0) {
      const paths = applications.flatMap((application) =>
        application.paths.filter((path): path is string => !!path)
      );
      const bucket = storage.from(VISITOR_BUCKET);
      for (let i = 0; i < paths.length; i += REMOVE_CHUNK_SIZE) {
        const { error } = await bucket.remove(paths.slice(i, i + REMOVE_CHUNK_SIZE));
        if (error) return new Error(error.message);
      }

      await rows.remove(applications.map((application) => application.id));
    }

    await rows.detach(userId);
    return null;
  } catch (error) {
    return error instanceof Error ? error : new Error(String(error));
  }
}

// Run with `deno test supabase/functions/_shared/delete_user_files_test.ts`.
// Needs no network: Storage is a fake kept in memory. It uses only
// `Deno.test` and `node:assert`, so Node 22 can run it too
// (`node --experimental-strip-types`, with a `Deno.test` shim).

import assert from "node:assert/strict";
import {
  APPLICATION_BUCKETS,
  deleteUserFiles,
  deleteVisitorApplications,
  type StorageBucket,
  type StorageClient,
  type VisitorApplicationRows,
} from "./delete_user_files.ts";

/// An in memory Storage. Files are full paths per bucket. `list` returns the
/// direct children of a folder, sorted and paged like the real one, and a
/// child that has more files below it comes back as a folder (`id: null`).
class FakeStorage implements StorageClient {
  buckets = new Map<string, Set<string>>();
  removeCalls: string[][] = [];
  listError: { bucket: string; message: string } | null = null;

  constructor(files: Record<string, string[]>) {
    for (const name of [...APPLICATION_BUCKETS, "visitor-documents"]) {
      this.buckets.set(name, new Set(files[name] ?? []));
    }
  }

  paths(bucket: string): string[] {
    return [...this.buckets.get(bucket)!].sort();
  }

  from(bucket: string): StorageBucket {
    const files = this.buckets.get(bucket)!;
    return {
      list: (folder, { limit, offset }) => {
        if (this.listError?.bucket === bucket) {
          return Promise.resolve({
            data: null,
            error: { message: this.listError.message },
          });
        }
        const children = new Map<string, string | null>();
        for (const path of files) {
          if (!path.startsWith(`${folder}/`)) continue;
          const rest = path.slice(folder.length + 1).split("/");
          children.set(rest[0], rest.length === 1 ? `id:${path}` : null);
        }
        const entries = [...children]
          .sort(([a], [b]) => a.localeCompare(b))
          .slice(offset, offset + limit)
          .map(([name, id]) => ({ name, id }));
        return Promise.resolve({ data: entries, error: null });
      },
      remove: (paths) => {
        this.removeCalls.push(paths);
        for (const path of paths) files.delete(path);
        return Promise.resolve({ data: null, error: null });
      },
    };
  }
}

const ME = "user_2abc";
const SOMEONE = "user_2abd";
// A different id that starts with mine, to prove a folder is matched whole.
const LOOKALIKE = "user_2abcd";

function twoPeople(): FakeStorage {
  return new FakeStorage({
    "store-logos": [
      `${ME}/logo-1.png`,
      `${ME}/logo-2.png`,
      `${SOMEONE}/logo.png`,
      `${LOOKALIKE}/logo.png`,
    ],
    "application-documents": [
      `${ME}/app-1/id-1.jpg`,
      `${ME}/app-1/business-1.jpg`,
      `${ME}/app-2/id-2.jpg`,
      `${ME}/app-3/deeper/more/id-3.jpg`,
      `${SOMEONE}/app-9/id-9.jpg`,
      `${LOOKALIKE}/app-1/id-1.jpg`,
    ],
  });
}

Deno.test("removes every file the person has in both buckets", async () => {
  const storage = twoPeople();

  const error = await deleteUserFiles(storage, ME);

  assert.equal(error, null);
  assert.deepEqual(storage.paths("store-logos"), [
    `${LOOKALIKE}/logo.png`,
    `${SOMEONE}/logo.png`,
  ]);
  assert.deepEqual(storage.paths("application-documents"), [
    `${LOOKALIKE}/app-1/id-1.jpg`,
    `${SOMEONE}/app-9/id-9.jpg`,
  ]);
});

Deno.test("walks folders inside folders, and pages through long lists", async () => {
  const storage = twoPeople();

  // A page of 2 forces several list calls per folder.
  const error = await deleteUserFiles(storage, ME, 2);

  assert.equal(error, null);
  assert.equal(storage.paths("store-logos").some((p) => p.startsWith(`${ME}/`)), false);
  assert.equal(
    storage.paths("application-documents").some((p) => p.startsWith(`${ME}/`)),
    false,
  );
});

Deno.test("removes in chunks of at most 100 paths", async () => {
  const many = Array.from({ length: 250 }, (_, i) => `${ME}/app/file-${i}.jpg`);
  const storage = new FakeStorage({ "application-documents": many });

  const error = await deleteUserFiles(storage, ME);

  assert.equal(error, null);
  assert.deepEqual(storage.paths("application-documents"), []);
  assert.equal(storage.removeCalls.length, 3);
  assert.ok(storage.removeCalls.every((paths) => paths.length <= 100));
});

Deno.test("a second run is safe and changes nothing", async () => {
  const storage = twoPeople();
  await deleteUserFiles(storage, ME);
  const before = storage.removeCalls.length;

  const error = await deleteUserFiles(storage, ME);

  assert.equal(error, null);
  assert.equal(storage.removeCalls.length, before);
});

Deno.test("a person with no files is not an error", async () => {
  const storage = twoPeople();

  assert.equal(await deleteUserFiles(storage, "user_nobody"), null);
  assert.equal(storage.removeCalls.length, 0);
});

Deno.test("an unsafe id removes nothing and says so", async () => {
  for (const id of ["", "a/b", "..", "."]) {
    const storage = twoPeople();

    const error = await deleteUserFiles(storage, id);

    assert.ok(error instanceof Error, `id ${JSON.stringify(id)}`);
    assert.equal(storage.removeCalls.length, 0);
  }
});

Deno.test("a failure in one bucket does not stop the other", async () => {
  const storage = twoPeople();
  storage.listError = { bucket: "store-logos", message: "storage is down" };

  const error = await deleteUserFiles(storage, ME);

  assert.equal(error?.message, "storage is down");
  assert.equal(
    storage.paths("application-documents").some((p) => p.startsWith(`${ME}/`)),
    false,
  );
});

// Visitor applications (spec 0014, AC-14). The rows say which files to remove.

/// An in memory `seller_applications` that records the order of every call
/// against the storage, so the order can be asserted.
class FakeRows implements VisitorApplicationRows {
  rows: { id: string; paths: (string | null)[] }[];
  log: string[];
  failRemove = false;

  constructor(rows: { id: string; paths: (string | null)[] }[], log: string[]) {
    this.rows = rows;
    this.log = log;
  }

  list(_userId: string) {
    this.log.push("list");
    return Promise.resolve([...this.rows]);
  }

  remove(ids: string[]) {
    this.log.push("rows");
    if (this.failRemove) return Promise.reject(new Error("rows are locked"));
    this.rows = this.rows.filter((row) => !ids.includes(row.id));
    return Promise.resolve();
  }
}

const VISITOR_FILES = [
  "anon_1/app-1/id-1.jpg",
  "anon_1/app-1/logo-1.png",
  "anon_2/app-2/id-2.jpg",
];

Deno.test("removes the files named on the rows, then the rows", async () => {
  const storage = new FakeStorage({ "visitor-documents": VISITOR_FILES });
  const log: string[] = [];
  const original = storage.from.bind(storage);
  storage.from = (bucket) => {
    const handle = original(bucket);
    return {
      ...handle,
      remove: (paths) => {
        log.push("files");
        return handle.remove(paths);
      },
    };
  };
  const rows = new FakeRows([
    { id: "a1", paths: ["anon_1/app-1/id-1.jpg", null, "anon_1/app-1/logo-1.png"] },
  ], log);

  const error = await deleteVisitorApplications(storage, rows, ME);

  assert.equal(error, null);
  assert.deepEqual(log, ["list", "files", "rows"]);
  assert.deepEqual(storage.paths("visitor-documents"), ["anon_2/app-2/id-2.jpg"]);
  assert.deepEqual(rows.rows, []);
});

Deno.test("a file failure keeps the rows so a retry still has the paths", async () => {
  const storage = new FakeStorage({ "visitor-documents": VISITOR_FILES });
  storage.from = () => ({
    list: () => Promise.resolve({ data: [], error: null }),
    remove: () => Promise.resolve({ data: null, error: { message: "storage is down" } }),
  });
  const rows = new FakeRows([{ id: "a1", paths: ["anon_1/app-1/id-1.jpg"] }], []);

  const error = await deleteVisitorApplications(storage, rows, ME);

  assert.equal(error?.message, "storage is down");
  assert.equal(rows.rows.length, 1);
});

Deno.test("a row failure is reported, and a rerun finishes the job", async () => {
  const storage = new FakeStorage({ "visitor-documents": VISITOR_FILES });
  const rows = new FakeRows([{ id: "a1", paths: ["anon_1/app-1/id-1.jpg"] }], []);
  rows.failRemove = true;

  assert.equal((await deleteVisitorApplications(storage, rows, ME))?.message, "rows are locked");

  rows.failRemove = false;
  assert.equal(await deleteVisitorApplications(storage, rows, ME), null);
  assert.deepEqual(rows.rows, []);
});

Deno.test("no visitor applications is not an error and removes nothing", async () => {
  const storage = new FakeStorage({ "visitor-documents": VISITOR_FILES });
  const rows = new FakeRows([], []);

  assert.equal(await deleteVisitorApplications(storage, rows, ME), null);
  assert.equal(storage.removeCalls.length, 0);
});

Deno.test("a list failure is returned and nothing is removed", async () => {
  const storage = new FakeStorage({ "visitor-documents": VISITOR_FILES });
  const rows = new FakeRows([], []);
  rows.list = () => Promise.reject(new Error("db is down"));

  assert.equal((await deleteVisitorApplications(storage, rows, ME))?.message, "db is down");
  assert.equal(storage.removeCalls.length, 0);
});

Deno.test("an empty user id removes nothing and says so", async () => {
  const storage = new FakeStorage({ "visitor-documents": VISITOR_FILES });
  const rows = new FakeRows([{ id: "a1", paths: ["anon_1/app-1/id-1.jpg"] }], []);

  assert.ok((await deleteVisitorApplications(storage, rows, "")) instanceof Error);
  assert.equal(rows.rows.length, 1);
});

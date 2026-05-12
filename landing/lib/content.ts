import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';

const contentDir = path.join(process.cwd(), 'content');

export interface BlogPost {
  slug: string;
  title: string;
  date: string;
  description: string;
  author: string;
  tags: string[];
  markdown: string;
  readingTime: number;
}

export interface DocsPage {
  slugPath: string[];
  title: string;
  description: string;
  order: number;
  section: string;
  markdown: string;
}

export interface ChangelogEntry {
  version: string;
  date: string;
  markdown: string;
}

function readingTime(text: string): number {
  return Math.max(1, Math.ceil(text.split(/\s+/).length / 200));
}

function readMd(filePath: string) {
  const raw = fs.readFileSync(filePath, 'utf8');
  return matter(raw);
}

export function getAllBlogPosts(): BlogPost[] {
  const dir = path.join(contentDir, 'blog');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter(f => f.endsWith('.md'))
    .map(file => {
      const slug = file.replace(/\.md$/, '');
      const { data, content } = readMd(path.join(dir, file));
      return {
        slug,
        title: data.title ?? 'Untitled',
        date: data.date ?? '',
        description: data.description ?? '',
        author: data.author ?? 'Glaqz',
        tags: data.tags ?? [],
        markdown: content,
        readingTime: readingTime(content),
      };
    })
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
}

export function getBlogPost(slug: string): BlogPost | null {
  const filePath = path.join(contentDir, 'blog', `${slug}.md`);
  if (!fs.existsSync(filePath)) return null;
  const { data, content } = readMd(filePath);
  return {
    slug,
    title: data.title ?? 'Untitled',
    date: data.date ?? '',
    description: data.description ?? '',
    author: data.author ?? 'Glaqz',
    tags: data.tags ?? [],
    markdown: content,
    readingTime: readingTime(content),
  };
}

export function getAllDocPages(): DocsPage[] {
  const dir = path.join(contentDir, 'docs');
  if (!fs.existsSync(dir)) return [];

  const collect = (d: string, prefix: string[] = []): DocsPage[] => {
    const entries = fs.readdirSync(d, { withFileTypes: true });
    const pages: DocsPage[] = [];
    for (const entry of entries) {
      if (entry.isDirectory()) {
        pages.push(...collect(path.join(d, entry.name), [...prefix, entry.name]));
      } else if (entry.name.endsWith('.md')) {
        const { data, content } = readMd(path.join(d, entry.name));
        pages.push({
          slugPath: [...prefix, entry.name.replace(/\.md$/, '')],
          title: data.title ?? 'Untitled',
          description: data.description ?? '',
          order: data.order ?? 99,
          section: data.section ?? 'General',
          markdown: content,
        });
      }
    }
    return pages;
  };

  return collect(dir).sort((a, b) => a.order - b.order);
}

export function getDocPage(slugPath: string[]): DocsPage | null {
  const filePath = path.join(contentDir, 'docs', ...slugPath) + '.md';
  if (!fs.existsSync(filePath)) return null;
  const { data, content } = readMd(filePath);
  return {
    slugPath,
    title: data.title ?? 'Untitled',
    description: data.description ?? '',
    order: data.order ?? 99,
    section: data.section ?? 'General',
    markdown: content,
  };
}

export function getAllChangelog(): ChangelogEntry[] {
  const dir = path.join(contentDir, 'changelog');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter(f => f.endsWith('.md'))
    .map(file => {
      const { data, content } = readMd(path.join(dir, file));
      return {
        version: data.version ?? file.replace(/\.md$/, ''),
        date: data.date ?? '',
        markdown: content,
      };
    })
    .sort((a, b) => {
      const n = (v: string) => v.replace(/^v/, '').split('.').map(Number).reduce((s, x, i) => s + x * Math.pow(1000, 2 - i), 0);
      return n(b.version) - n(a.version);
    });
}

import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';
export const metadata: Metadata = { title: 'Cabinet Dentaire · Soins dentaires', description: 'Prenez rendez-vous en ligne avec votre cabinet dentaire.' };
export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) { return <html lang="fr"><body>{children}</body></html>; }

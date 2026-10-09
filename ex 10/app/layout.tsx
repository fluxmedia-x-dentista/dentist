import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'DentaFlex | Dental Equipment', description: 'Thoughtfully selected dental equipment and dependable guidance for modern dental practices.' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body>{children}</body></html>; }

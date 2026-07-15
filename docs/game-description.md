# Drawing Space — Dokumentasi Game

## Ringkasan

**Drawing Space** adalah game petualangan 2D top-down untuk iPhone dan iPad. Pemain terbangun di kapal luar angkasa yang rusak dan harus memperbaiki sistem kapal dengan menjelajah ruangan serta menyelesaikan tantangan menggambar.

Gambar pemain dikenali oleh model Core ML. Setiap gambar yang benar akan memperbaiki sistem tertentu dan membuka bagian cerita berikutnya.

## Tujuan Utama

Pemain harus:

1. Masuk ke Laboratory.
2. Memulihkan Intelligence AI.
3. Memperbaiki Engine secara bertahap.
4. Mengambil advanced tools dari Storage.
5. Menyelesaikan perbaikan Engine hingga 100%.
6. Memperbaiki Cockpit dan menyelesaikan permainan.

## Ruangan

| Ruangan | Fungsi | Syarat akses |
|---|---|---|
| Sleeping Room | Lokasi awal pemain | Terbuka sejak awal |
| Laboratory | Memulihkan AI | Terbuka sejak awal melalui jalur Sleeping Room |
| Engine Room | Memperbaiki mesin kapal | Intelligence 40 dan seluruh misi Lab selesai |
| Kitchen | Memulihkan Energy | Terbuka sejak awal |
| Storage | Mendapatkan advanced tools | Engine Progress 60 |
| Cockpit | Menyelesaikan penerbangan | Intelligence 100 dan Engine Progress 100 |

Tidak ada jalan langsung dari Laboratory ke Storage. Pemain harus melewati Sleeping Room dan Engine Room untuk menuju Storage.

## Kontrol

### Menggunakan jari

- Gerakkan joystick di kiri bawah untuk berjalan.
- Dekati stasiun untuk menampilkan tombol `REPAIR`.
- Tekan tombol map untuk membuka tactical map.

### Menggunakan Apple Pencil

- Sentuh titik tujuan untuk menggerakkan karakter.
- Tekanan ringan membuat karakter bergerak lebih lambat.
- Tekanan kuat membuat karakter bergerak lebih cepat.

### Tantangan menggambar

- Gambar dapat dibuat dengan jari atau Apple Pencil.
- Tekan submit untuk memeriksa gambar.
- Gambar diterima jika label sesuai dan confidence minimal 50%.
- Jika gagal, pemain dapat mencoba kembali tanpa kehilangan progres.

## Status Pemain dan Kapal

HUD menampilkan tiga nilai utama:

| Status | Rentang | Keterangan |
|---|---:|---|
| Energy | 0–100 | Kondisi pemain |
| Intelligence | 10–100 | Kemampuan AI kapal |
| Engine Progress | 0–100 | Kondisi mesin kapal |

Energy bersifat lokal untuk pemain. Intelligence dan Engine Progress merupakan progres cerita kapal.

## Sistem Energy

- Energy maksimum: **100**.
- Energy berkurang **0,08 per detik**.
- Saat bergerak, konsumsi Energy menjadi **1,5 kali**.
- Gangguan listrik mengurangi **5 Energy**.
- Makanan memulihkan **40 Energy**.
- Nilai Energy tidak dapat melebihi 100.
- Energy 0 menyebabkan **Game Over**.

## Kitchen

Kitchen menyediakan tantangan menggambar yang dapat diulang:

- `BANANA`
- `APPLE`
- `DONUT`
- `PIZZA`
- `CARROT`

Menyelesaikan tantangan Kitchen hanya memulihkan Energy. Kitchen tidak menambah Intelligence atau Engine Progress.

## Alur Cerita dan Misi

### 1. Sleeping Room

Tujuan awal adalah menemukan dan memasuki Laboratory.

| Misi | Aksi |
|---|---|
| Reach the Laboratory | Masuk ke Laboratory |

### 2. Laboratory

Ketiga misi dapat diselesaikan dalam urutan bebas.

| Misi | Gambar | Reward |
|---|---|---:|
| Repair Communication Terminal | `RADIO` | +10 Intelligence |
| Repair Memory Processor | `BRAIN` | +10 Intelligence |
| Repair Navigation Scanner | `BINOCULARS` | +10 Intelligence |

Setelah semuanya selesai, Intelligence menjadi 40 dan pintu Engine Room terbuka.

### 3. Engine Phase One

Misi harus diselesaikan sesuai urutan.

| Urutan | Misi | Gambar | Reward |
|---:|---|---|---:|
| 1 | Reconnect Power Connector | `POWER OUTLET` | +5 Engine |
| 2 | Repair Ignition Coil | `LIGHTBULB` | +5 Engine |

Engine Progress 10 mengaktifkan basic power.

### 4. Engine Phase Two

| Urutan | Misi | Gambar | Reward |
|---:|---|---|---:|
| 1 | Restore Cooling Valve | `FAN` | +10 Engine, +3 Intelligence |
| 2 | Repair Control Relay | `COMPUTER MONITOR` | +10 Engine, +3 Intelligence |
| 3 | Reconnect Reactor Link | `SATELLITE` | +10 Engine, +4 Intelligence |
| 4 | Repair Pressure Feed | `FIRE HYDRANT` | +10 Engine, +5 Intelligence |
| 5 | Calibrate Engine Port | `SCREWDRIVER` | +10 Engine, +5 Intelligence |

Pada Engine Progress 40 terjadi gangguan listrik. Setelah seluruh misi selesai, Engine Progress dan Intelligence menjadi 60.

Perbaikan berikutnya diblokir sampai pemain mengambil advanced tools dari Storage.

### 5. Storage

Storage hanya dapat dicapai melalui jalur Engine–Storage.

| Urutan | Misi | Gambar |
|---:|---|---|
| 1 | Repair Storage Controller | `KEY` |
| 2 | Repair Tool Terminal | `CALCULATOR` |
| 3 | Repair Robotic Arm | `HAND` |
| 4 | Repair Calibration Unit | `SCREWDRIVER` |

Misi terakhir memberikan advanced tools. Pemain kemudian harus kembali ke Engine Room.

### 6. Engine Final

| Urutan | Misi | Gambar | Reward |
|---:|---|---|---:|
| 1 | Stabilize the Reactor | `SUN` | +8 Engine, +8 Intelligence |
| 2 | Reconnect Engine Core | `POWER OUTLET` | +8 Engine, +8 Intelligence |
| 3 | Calibrate Propulsion | `ROCKET` | +8 Engine, +8 Intelligence |
| 4 | Restart Cooling | `FAN` | +8 Engine, +8 Intelligence |
| 5 | Synchronize Navigation | `SATELLITE` | +8 Engine, +8 Intelligence |

Setelah semuanya selesai, Intelligence dan Engine Progress menjadi 100. Main power pulih dan Cockpit terbuka.

### 7. Cockpit

| Urutan | Misi | Gambar |
|---:|---|---|
| 1 | Restore Navigation Control | `SHIP` |
| 2 | Reconnect Communications | `RADIO` |
| 3 | Calibrate Flight Console | `COMPUTER KEYBOARD` |

Masuk ke Cockpit belum menyelesaikan game. Victory hanya terjadi setelah ketiga misi Cockpit selesai.

## Keadaan Listrik

| Keadaan | Efek |
|---|---|
| Emergency | Lingkungan gelap dengan cahaya darurat |
| Basic Power | Pada Engine 10%, vignette dimatikan dan seluruh map menjadi terang |
| Disrupted | Pada Engine 40%, vignette menyala kembali, map menjadi gelap, dan Energy berkurang |
| Fully Restored | Pencahayaan penuh dan sistem kapal aktif |

## Objective dan Tactical Map

Objective tracker menunjukkan misi aktif dan progresnya. Tactical map menampilkan:

- ruangan;
- posisi pemain;
- stasiun aktif dan selesai;
- pintu terkunci atau terbuka;
- Kitchen, Storage, dan Cockpit;
- posisi teammate jika tersedia.

Map dan collision dunia menggunakan data layout yang sama agar posisi dinding, pintu, dan koridor tetap konsisten.

## Checkpoint dan Penyimpanan

Checkpoint tersedia di:

- Sleeping Room;
- Laboratory;
- Engine Phase One;
- gangguan listrik;
- Engine Progress 60;
- Storage;
- Engine Final;
- Cockpit.

Progres disimpan otomatis menggunakan SwiftData. Save berisi progres terbaru dan snapshot checkpoint.

Saat memilih retry setelah Game Over:

- progres kembali ke checkpoint terakhir;
- pemain kembali ke safe spawn;
- perubahan setelah checkpoint dibatalkan;
- Energy dipulihkan minimal menjadi 50.

## Game Over dan Victory

### Game Over

Game Over terjadi saat Energy mencapai 0. Drawing challenge yang sedang terbuka akan ditutup dan pemain dapat mengulang dari checkpoint.

### Victory

Victory menampilkan ringkasan:

- waktu bermain;
- jumlah percobaan menggambar;
- objective yang selesai;
- jumlah pemulihan di Kitchen;
- Energy terakhir.

Pemain dapat kembali ke Main Menu atau memilih `PLAY AGAIN`. Opsi ini menghapus save dan memulai kembali dari Sleeping Room.

Main Menu menyediakan dua pilihan:

- `CONTINUE GAME` untuk melanjutkan save terakhir;
- `NEW GAME` untuk menghapus progres lama dan memulai dari awal.

## Teknologi

- **UIKit** sebagai host aplikasi.
- **SpriteKit** untuk dunia game, gerakan, collision, dan efek.
- **SwiftUI** untuk HUD dan tactical map.
- **PencilKit** untuk kanvas menggambar.
- **Core ML** untuk pengenalan doodle.
- **SwiftData** untuk penyimpanan progres.

Versi saat ini memakai authority lokal. Fondasi command dan shared state telah disiapkan untuk multiplayer, tetapi transport jaringan belum diimplementasikan.

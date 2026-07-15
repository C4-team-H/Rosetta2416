# Drawing Space — Deskripsi dan Definisi Game

## Identitas Game

| Elemen | Definisi |
|---|---|
| Judul | **Drawing Space** |
| Genre | Eksplorasi 2D, drawing challenge, dan casual survival |
| Perspektif | Top-down 2D |
| Platform | iOS dan iPadOS |
| Mode permainan | Single-player pada implementasi saat ini, dengan fondasi tactical map untuk co-op dua pemain |
| Teknologi utama | SpriteKit, SwiftUI, PencilKit, dan Core ML |
| Durasi sesi | Sesi pendek berbasis penyelesaian lima tantangan gambar |

## Definisi Game

**Drawing Space** adalah game eksplorasi 2D yang mengajak pemain menjelajahi sebuah stasiun gelap, menemukan lokasi misi, dan menyelesaikan tantangan dengan menggambar objek menggunakan jari atau Apple Pencil. Setiap gambar dianalisis secara langsung oleh model klasifikasi Core ML. Pemain harus menyelesaikan seluruh tantangan sebelum energi karakter habis.

Game ini menggabungkan tiga aktivitas utama: navigasi ruang, kreativitas menggambar, dan pengelolaan energi. Eksplorasi menentukan lokasi yang harus dicapai, tantangan menggambar menjadi cara utama menyelesaikan misi, sedangkan energi memberikan tekanan waktu dan risiko `Game Over`.

## Deskripsi Singkat

Jelajahi stasiun yang gelap, temukan titik misi, lalu gambarkan objek yang diminta sebelum energimu habis. Gunakan tactical map untuk membaca ruangan dan jalur, isi kembali energi di Kitchen, dan selesaikan lima tantangan gambar untuk memenangkan permainan.

## Elevator Pitch

> **Drawing Space** adalah game eksplorasi top-down di mana kemampuan menggambar menjadi alat utama untuk bertahan hidup dan menyelesaikan misi.

## Premis Permainan

Pemain berada di dalam sebuah stasiun yang terdiri dari beberapa ruangan dan koridor. Jarak pandang dibatasi oleh pencahayaan seperti cahaya lilin, sehingga pemain perlu mengingat jalur atau membuka tactical map untuk memahami posisi ruangan, pintu, misi, dan objek penting.

Di beberapa lokasi terdapat easel atau stasiun tantangan. Ketika pemain mendekatinya, tombol interaksi akan muncul dan membuka kanvas menggambar. Pemain harus menggambar objek yang diminta dengan cukup jelas agar model Core ML dapat mengenalinya.

Energi pemain terus berkurang selama permainan. Jika energi habis sebelum seluruh misi selesai, permainan berakhir. Pemain dapat menuju Kitchen dan menyelesaikan tantangan menggambar makanan untuk memulihkan energi.

## Tujuan Pemain

Tujuan utama pemain adalah menyelesaikan **lima tantangan gambar** sebelum energi mencapai nol.

Daftar tantangan utama saat ini adalah:

1. Buku
2. Kupu-kupu
3. Kaktus
4. Lilin
5. Ikan

Urutan tantangan diacak pada setiap sesi permainan.

## Core Gameplay Loop

```text
Membaca map dan lingkungan
        ↓
Menjelajahi ruangan
        ↓
Menemukan stasiun misi
        ↓
Menggambar objek yang diminta
        ↓
Core ML memeriksa hasil gambar
        ↓
Misi berhasil atau pemain mencoba kembali
        ↓
Mengelola energi dan menuju misi berikutnya
```

Dalam bentuk singkat:

> **Explore → Find → Draw → Recognize → Survive → Repeat**

## Mekanik Utama

### 1. Eksplorasi Top-Down

Pemain bergerak di dunia 2D berukuran `2000 × 2000` yang memiliki dinding, pintu, koridor, dan beberapa ruangan utama:

- Sleeping Room sebagai lokasi awal pemain;
- Engine Room sebagai salah satu lokasi tantangan;
- Lab sebagai lokasi tantangan lainnya;
- Kitchen sebagai lokasi pemulihan energi.

Kamera mengikuti posisi pemain dan menampilkan sebagian kecil lingkungan di sekitarnya.

### 2. Sistem Pergerakan

Pemain dapat bergerak menggunakan:

- joystick virtual untuk kontrol arah secara langsung;
- Apple Pencil untuk menentukan target pergerakan;
- tekanan Apple Pencil untuk memengaruhi kecepatan gerak menuju target.

Pergerakan dibatasi oleh ukuran dunia dan sistem tabrakan dinding. Saat menyentuh dinding, karakter mencoba bergerak mengikuti sisi dinding agar kontrol tetap terasa halus.

### 3. Tantangan Menggambar

Ketika pemain berada cukup dekat dengan easel, tombol `DRAW` akan muncul. Tombol tersebut membuka kanvas PencilKit tempat pemain dapat menggambar dengan jari atau Apple Pencil.

Setelah gambar dikirim:

1. gambar dirender dengan latar putih;
2. gambar diproses oleh model Core ML;
3. hasil prediksi dibandingkan dengan objek yang sedang diminta;
4. tantangan dinyatakan berhasil jika label prediksi sesuai;
5. jika belum sesuai, pemain dapat menghapus atau menggambar ulang.

### 4. Sistem Energi

Pemain memulai permainan dengan energi penuh. Energi berkurang secara terus-menerus selama simulasi permainan berlangsung.

Konsekuensi energi:

- energi di atas 50% ditampilkan dengan warna hijau;
- energi antara 20%–50% ditampilkan dengan warna oranye;
- energi di bawah 20% ditampilkan dengan warna merah;
- energi 0% menyebabkan `Game Over` dan menghentikan pergerakan pemain.

### 5. Pemulihan Energi

Kitchen memiliki stasiun makanan yang menampilkan tombol `EAT`. Untuk memperoleh energi, pemain tetap harus menyelesaikan tantangan menggambar makanan.

Objek makanan dipilih secara acak dari:

- pisang;
- apel;
- donat;
- pizza.

Gambar makanan yang berhasil dikenali akan memulihkan **40% dari energi maksimum**, tanpa melewati batas energi penuh.

### 6. Tactical Map

Tombol map berada di bagian kanan atas layar gameplay. Map ditampilkan sebagai overlay layar penuh dan memperlihatkan:

- bentuk seluruh ruangan dan koridor;
- dinding dan pintu;
- posisi pemain lokal;
- posisi teammate jika tersedia dan diizinkan oleh level;
- misi aktif dan misi selesai;
- area terkunci;
- objek penting;
- checkpoint.

Posisi dunia SpriteKit dikonversi menjadi posisi map SwiftUI dengan normalisasi koordinat, aspect-fit, padding, pembalikan sumbu Y, dan pembatasan marker agar tidak keluar dari area map.

Saat map terbuka, input pergerakan pemain lokal dihentikan. Simulasi SpriteKit dan pembaruan multiplayer dapat tetap berjalan agar satu pemain tidak menghentikan permainan pemain lainnya.

### 7. Visibilitas Terbatas

Efek pencahayaan lilin membatasi area yang terlihat di sekitar pemain. Mekanik ini memberikan fungsi penting kepada tactical map dan membuat eksplorasi terasa lebih menegangkan.

## Kontrol Permainan

| Kontrol | Fungsi |
|---|---|
| Joystick virtual | Menggerakkan karakter secara bebas |
| Tap atau drag Apple Pencil | Menentukan tujuan gerak karakter |
| Tekanan Apple Pencil | Mengatur pengali kecepatan menuju target |
| Tombol `DRAW` | Membuka tantangan menggambar utama |
| Tombol `EAT` | Membuka tantangan makanan untuk memulihkan energi |
| Tombol map | Membuka tactical map layar penuh |
| `Batal` | Menutup kanvas tanpa mengirim gambar |
| `Hapus` | Menghapus seluruh gambar pada kanvas |
| `Kirim` | Mengirim gambar untuk diklasifikasikan |

## Kondisi Menang

Pemain memenangkan sesi ketika seluruh lima tantangan gambar berhasil diselesaikan. Sistem kemudian:

- mengubah stasiun tantangan menjadi status selesai;
- memperbarui marker misi pada tactical map;
- menampilkan pesan `SEMUA TANTANGAN BERHASIL!`.

## Kondisi Kalah

Pemain kalah ketika energi mencapai nol sebelum seluruh tantangan selesai. Karakter tidak lagi dapat bergerak dan layar `GAME OVER` ditampilkan bersama tombol untuk memulai ulang permainan.

Ketika permainan dimulai ulang:

- energi kembali penuh;
- progres tantangan kembali ke nol;
- urutan tantangan diacak ulang;
- posisi pemain kembali ke Sleeping Room;
- marker misi kembali menjadi aktif.

## Pilar Desain

### Eksplorasi

Pemain harus memahami hubungan antar-ruangan, mencari jalur yang dapat dilewati, dan menggunakan map untuk merencanakan perjalanan.

### Kreativitas yang Terukur

Menggambar bukan aktivitas dekoratif. Bentuk yang dibuat pemain menjadi input gameplay dan harus cukup terbaca oleh model klasifikasi.

### Tekanan Waktu Tidak Langsung

Tidak ada penghitung waktu tradisional. Energi yang terus berkurang berfungsi sebagai batas waktu sekaligus sumber daya yang harus dikelola.

### Informasi dan Koordinasi

Tactical map menyatukan informasi lokasi, status misi, dan posisi pemain. Fondasi ini disiapkan untuk mendukung koordinasi dua pemain pada pengembangan multiplayer selanjutnya.

## Pengalaman yang Ingin Dihasilkan

Game dirancang untuk menghasilkan kombinasi pengalaman berikut:

- rasa ingin tahu ketika menjelajahi area gelap;
- urgensi karena energi terus berkurang;
- kepuasan ketika gambar berhasil dikenali;
- perencanaan ketika memilih antara melanjutkan misi atau mencari energi;
- koordinasi posisi dan tujuan ketika mode co-op diaktifkan.

## Target Pemain

Drawing Space cocok untuk:

- pemain casual yang menyukai sesi permainan singkat;
- pemain yang menikmati aktivitas menggambar;
- pengguna iPad dan Apple Pencil;
- pemain yang menyukai eksplorasi dan penyelesaian misi ringan;
- dua pemain yang ingin bekerja sama setelah sistem multiplayer terhubung sepenuhnya.

## Gaya Visual

Visual game menggunakan pendekatan 2D sederhana dan mudah dibaca:

- lingkungan berwarna gelap dengan grid lantai;
- dinding dan ruangan menggunakan warna slate;
- cahaya lilin menciptakan area pandang terbatas;
- objek interaktif memiliki glow dan animasi pulse;
- warna hijau menandakan keberhasilan atau energi aman;
- warna oranye menandakan makanan dan kondisi waspada;
- warna merah menandakan energi kritis atau kegagalan;
- tactical map menggunakan panel dark navy, garis cyan, dan marker berkontras tinggi.

## Nilai Pembeda

Keunikan Drawing Space berasal dari hubungan langsung antara menggambar dan eksplorasi. Pemain tidak menyelesaikan misi dengan memilih jawaban atau menekan tombol biasa, tetapi dengan membuat gambar yang benar-benar dinilai oleh model machine learning pada perangkat.

Kombinasi tersebut menghasilkan identitas yang jelas:

> **Game eksplorasi di mana kemampuan menggambar menjadi cara pemain berinteraksi, bertahan, dan menyelesaikan misi.**

## Status Implementasi Saat Ini

Fitur yang telah tersedia:

- menu utama dan transisi menuju gameplay;
- eksplorasi top-down dengan kamera mengikuti pemain;
- joystick dan navigasi Apple Pencil;
- collision dinding dan batas dunia;
- lima tantangan gambar utama;
- klasifikasi gambar menggunakan Core ML;
- stasiun makanan dan pemulihan energi;
- sistem energi, progres, menang, kalah, dan restart;
- pencahayaan lilin;
- tactical map layar penuh;
- marker pemain, teammate, pintu, misi, objek penting, dan checkpoint;
- state teammate untuk connected, reconnecting, dan disconnected.

Fitur yang fondasinya telah disiapkan tetapi belum terlihat terhubung sepenuhnya pada implementasi saat ini:

- sinkronisasi jaringan real-time untuk pemain kedua;
- gameplay co-op end-to-end;
- zoom dan pan interaktif pada tactical map;
- audio dan musik permainan;
- progression antarsesi atau penyimpanan progres permanen.

## Definisi Produk Akhir

Drawing Space dapat dikembangkan sebagai game co-op eksplorasi kreatif untuk iPad, di mana dua pemain menjelajahi stasiun, berbagi informasi melalui tactical map, mengelola energi, dan menyelesaikan misi dengan menggambar objek menggunakan Apple Pencil. Model machine learning lokal memberikan respons langsung tanpa menjadikan koneksi internet sebagai syarat untuk memeriksa gambar.

-- =====================================================================
-- SQL 21: kunci klaim baru pada barang yang sudah diklaim
-- ---------------------------------------------------------------------
-- Begitu ada klaim berstatus disetujui atau selesai pada sebuah
-- postingan, postingan itu sedang proses serah terima: pengguna lain
-- tidak boleh mengajukan klaim baru. Memperluas lf_batas_klaim yang
-- sudah ada (batas harian + larangan klaim aktif ganda per pengguna).
-- =====================================================================

create or replace function public.lf_batas_klaim()
returns trigger
language plpgsql
as $$
declare
  batas int;
  jumlah int;
begin
  if exists (
    select 1 from public.lf_claims
     where post_id = new.post_id
       and user_id <> new.user_id
       and status in ('disetujui', 'selesai')
  ) then
    raise exception 'Barang ini sudah diklaim pengguna lain dan sedang proses serah terima.';
  end if;
  select case when terverifikasi then 10 else 5 end into batas
    from public.lf_profiles where id = new.user_id;
  select count(*) into jumlah
    from public.lf_claims
   where user_id = new.user_id
     and created_at > now() - interval '24 hours';
  if jumlah >= coalesce(batas, 5) then
    raise exception 'Batas klaim harian tercapai. Coba lagi besok.';
  end if;
  if exists (
    select 1 from public.lf_claims
     where user_id = new.user_id
       and post_id = new.post_id
       and status in ('menunggu', 'disetujui')
  ) then
    raise exception 'Kamu sudah punya klaim aktif pada postingan ini.';
  end if;
  return new;
end;
$$;

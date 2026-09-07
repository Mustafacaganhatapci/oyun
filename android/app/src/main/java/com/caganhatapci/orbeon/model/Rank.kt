package com.caganhatapci.orbeon.model

import androidx.compose.ui.graphics.Color
import com.caganhatapci.orbeon.services.LeaderboardService

/**
 * Sıralamadaki rütbeler — iOS'takiyle birebir aynı eşikler ve renkler.
 *
 * Elli satırlık düz bir liste bir şey anlatmıyor: 41. olmakla 39. olmak
 * arasında bir his farkı yok. Rütbe onu veriyor — hangi kümede olduğunu
 * görüyorsun, bir üstündeki kümeye ne kadar kaldığını da.
 *
 * Renkler TEMAYA BAĞLI DEĞİL, sabit. Bir rütbe herkeste aynı görünmeli,
 * yoksa "mor olan iyidir" gibi ortak bir dil kurulamaz.
 */
enum class Rank(val titleRes: Int, val color: Color) {
    // Griden turuncuya, altına, camgöbeğine, mora, en üstte beyaza.
    // Sıcaklık değil PARLAKLIK artıyor — yukarı çıkmak "daha aydınlık".
    SPARK(com.caganhatapci.orbeon.R.string.rank_spark, Color(0xFF8A94A6)),
    EMBER(com.caganhatapci.orbeon.R.string.rank_ember, Color(0xFFE8873D)),
    BEACON(com.caganhatapci.orbeon.R.string.rank_beacon, Color(0xFFF0C43B)),
    PULSAR(com.caganhatapci.orbeon.R.string.rank_pulsar, Color(0xFF45C7E0)),
    QUASAR(com.caganhatapci.orbeon.R.string.rank_quasar, Color(0xFFA36BF5)),
    ZENITH(com.caganhatapci.orbeon.R.string.rank_zenith, Color(0xFFEBF2FF));

    companion object {
        /**
         * Sonsuz modda bu rütbeye giriş skoru.
         *
         * Eşikler doldurmaların tavanına göre ayarlı: en iyi doldurma 33
         * atlıyor, yani Pulsar'a ancak değiyor. Kuazar ve Zirve'ye yalnızca
         * gerçek insanlar çıkabiliyor — en üst iki basamak uydurma bir isimle
         * dolmasın.
         */
        val ENDLESS_FLOOR = intArrayOf(1, 8, 16, 28, 45, 70)

        /**
         * Hız turunda bu rütbenin ÜST süre sınırı (saniye) — altında kalan
         * girer. İlk eleman sonsuz: en alt rütbeye herkes girer.
         *
         * Eşikler baştan çok iyimserdi: Zirve 50 saniye istiyordu, oysa on
         * bölümün gerçekte inebildiği yer 1:59 civarı.
         */
        val SPEEDRUN_CEILING = doubleArrayOf(Double.MAX_VALUE, 240.0, 200.0, 170.0, 145.0, 125.0)

        /** Bir sonucun rütbesi */
        fun of(value: Double, mode: LeaderboardService.Mode): Rank {
            var found = SPARK
            if (mode == LeaderboardService.Mode.ENDLESS) {
                for (r in entries) if (value.toInt() >= ENDLESS_FLOOR[r.ordinal]) found = r
            } else {
                for (r in entries) if (value < SPEEDRUN_CEILING[r.ordinal]) found = r
            }
            return found
        }

        private fun clock(t: Double): String =
            String.format("%d:%02d", t.toInt() / 60, t.toInt() % 60)

        /** Rütbe aralığının okunur hâli — cetvelde gösteriliyor */
        fun rangeText(rank: Rank, mode: LeaderboardService.Mode): String {
            val i = rank.ordinal
            return if (mode == LeaderboardService.Mode.ENDLESS) {
                val low = ENDLESS_FLOOR[i]
                if (i == entries.size - 1) "$low+" else "$low–${ENDLESS_FLOOR[i + 1] - 1}"
            } else {
                when {
                    i == 0 -> "${clock(SPEEDRUN_CEILING[1])}+"
                    i == entries.size - 1 -> "< ${clock(SPEEDRUN_CEILING[i])}"
                    else -> "${clock(SPEEDRUN_CEILING[i + 1])}–${clock(SPEEDRUN_CEILING[i])}"
                }
            }
        }
    }
}

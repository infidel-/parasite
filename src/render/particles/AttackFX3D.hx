package render.particles;

import render.RenderConfig;

// a glowing procedural attack-FX sprite: a runtime-rasterized white SVG shape (swing arc / fist /
// claw / bolt / impact mark) tinted per kind via emissive, grown + faded over its life. spawned at
// a melee strike (keyed by the weapon's _AttackEffect) or stamped at a projectile impact. per kind
// it lies flat on the ground or stands upright, and may slide attacker->target. purely visual
class AttackFX3D extends Particle3D {
  var ax:Float; var ay:Float; var az:Float;   // attacker (swing origin) world pos
  var bx:Float; var by:Float; var bz:Float;   // target (strike) world pos
  var color:Int;              // emissive tint of the glowing shape
  var scale:Float;            // base scale (of Sprites.SIZE)
  var sweep:Float;            // roll swept over the life (radians) — the swing motion (upright kinds)
  var flat:Bool;              // lie flat on the ground (aligned to the swing) vs upright billboard
  var travel:Bool;           // slide from attacker to target over the life (e.g. a thrown punch)
  var travelMult:Float;       // travel speed multiplier (>1 lands before the life ends)
  var baseYaw:Float;          // ground-plane orientation of the swing (for flat kinds)
  var travelYaw:Float;        // in-plane roll pointing an upright travelling sprite (fist) at the target
  var shape:String;           // svg shape id / cache key
  var svg:String;             // white (tintable) shape markup
  var life:Float;             // total progress life (multiple of BASE_MS)
  var t:Float = 0.0;          // progress

  public function new(effect:String, ax:Float, ay:Float, az:Float, bx:Float, by:Float, bz:Float)
    {
      super();
      this.ax = ax; this.ay = ay; this.az = az;
      this.bx = bx; this.by = by; this.bz = bz;
      // per-kind tuning from the render config attack-FX table (typed lookup by kind key)
      var c = RenderConfig.ATTACK_FX.kinds;
      var k = switch (effect)
        {
          case 'SLASH_HEAVY': c.SLASH_HEAVY;
          case 'BLUNT': c.BLUNT;
          case 'PUNCH': c.PUNCH;
          case 'BITE': c.BITE;
          case 'STUN': c.STUN;
          case 'IMPACT': c.IMPACT;
          default: c.SLASH_LIGHT;
        };
      this.color = k.color;
      this.scale = k.scale;
      this.sweep = k.sweep;
      this.flat = k.flat;
      this.travel = k.travel;
      this.travelMult = k.travelMult;
      // swing direction attacker->target, on the ground plane
      var dx = bx - ax;
      var dz = bz - az;
      if (dx * dx + dz * dz < 0.0001)
        dz = 1;
      this.baseYaw = Math.atan2(dx, dz);
      // upright travelling sprite: roll so its "up" points along the on-screen swing direction
      this.travelYaw = Math.atan2(-dx, -dz);
      this.life = RenderConfig.ATTACK_FX.lifeMult;
      this.shape = shapeFor(effect);
      this.svg = svgFor(shape);
    }

// advance the arc; grows + fades in draw, dies at end of life
  override public function tick(dtMs:Float):Bool
    {
      t += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      return t < life;
    }

// draw the tinted glowing shape: anchored at the target (or sliding in from the attacker), grown +
// faded by progress, laid flat + swing-aligned or upright + roll-swept
  override public function draw(p:Paint3D):Void
    {
      var tex = p.sprites.svgTex(shape + ':' + RenderConfig.ATTACK_FX.px, svg, RenderConfig.ATTACK_FX.px);
      if (tex == null)
        return;
      var u = t / life;
      // position: a travelling kind slides attacker->target (eased), others sit at the strike
      var cx = bx;
      var cy = by;
      var cz = bz;
      if (travel)
        {
          var e = u * u * (3 - 2 * u) * travelMult;   // smoothstep thrust, sped up by travelMult
          if (e > 1)
            e = 1;
          cx = ax + (bx - ax) * e;
          cy = ay + (by - ay) * u;
          cz = az + (bz - az) * e;
        }
      // flat kinds lie on the ground yawed to the swing (bow away from the attacker); a travelling
      // fist points at the target; other upright kinds roll-sweep in their plane
      var orient = flat ? baseYaw + Math.PI : (travel ? travelYaw : sweep * (u - 0.5));
      p.sprites.paint(cx, cy, cz, tex, 1 - u, scale * (0.6 + 0.5 * u), flat, orient,
        Sprites.ORD_ACTOR + 1, color, RenderConfig.ATTACK_FX.emissiveInt);
    }

// maps an attack-effect kind to its shape
  static function shapeFor(effect:String):String
    {
      return switch (effect)
        {
          case 'BLUNT': 'bash';
          case 'PUNCH': 'fist';
          case 'BITE': 'claw3';
          case 'STUN': 'bolt';
          case 'IMPACT': 'curvedx';
          default: 'swoosh'; // SLASH_LIGHT / SLASH_HEAVY (light lies flat, heavy stands upright)
        };
    }

// white (tintable) svg markup for a shape id — rasterized + cached by Sprites.svgTex
  static function svgFor(shape:String):String
    {
      var vb = '0 0 100 100';
      var body = switch (shape)
        {
          case 'bash': // short chunky crescent — a blunt impact swipe
            '<path d="M22 72 Q 50 18 78 72 Q 50 48 22 72 Z" fill="#fff" opacity="0.5"/>' +
            '<path d="M30 70 Q 50 30 70 70 Q 50 52 30 70 Z" fill="#fff"/>';
          case 'fist': // the strength-attribute clenched fist (mirrors ui.UISvg.attrStr), tinted via emissive
            vb = '202 129 850 850';
            '<path d="M 379.0 405.0 L 369.0 413.0 L 353.0 431.0 L 344.0 445.0 L 334.0 466.0 L 323.0 498.0 L 316.0 527.0 L 313.0 547.0 L 313.0 574.0 L 318.0 596.0 L 326.0 614.0 L 335.0 629.0 L 386.0 695.0 L 461.0 786.0 L 473.0 801.0 L 477.0 805.5 L 479.0 820.0 L 478.0 820.5 L 477.0 841.0 L 476.0 841.5 L 475.0 859.0 L 474.0 859.5 L 472.0 885.5 L 471.0 886.0 L 469.0 912.0 L 468.0 912.5 L 468.0 922.0 L 466.0 931.5 L 466.0 943.0 L 468.0 945.0 L 475.0 947.0 L 838.0 947.0 L 842.0 946.0 L 846.0 943.0 L 846.0 930.5 L 845.0 930.0 L 845.0 921.0 L 844.0 920.5 L 838.0 856.5 L 837.0 856.0 L 837.0 846.5 L 835.0 837.5 L 834.0 809.5 L 835.0 806.5 L 840.0 800.5 L 875.0 755.0 L 895.0 723.0 L 910.0 692.0 L 922.0 658.0 L 931.0 619.0 L 936.0 583.0 L 938.0 538.0 L 939.0 537.0 L 939.0 494.0 L 924.0 506.0 L 913.0 512.0 L 893.0 518.0 L 884.0 519.0 L 864.0 518.0 L 839.0 510.0 L 823.0 499.0 L 812.0 487.0 L 807.0 479.0 L 795.0 493.0 L 779.0 505.0 L 769.0 510.0 L 747.0 516.0 L 723.0 516.0 L 709.0 513.0 L 691.0 505.0 L 679.0 497.0 L 672.0 510.0 L 663.0 522.0 L 643.0 540.0 L 620.0 553.0 L 610.0 557.0 L 590.0 562.0 L 591.0 564.0 L 609.0 573.0 L 629.0 587.0 L 648.0 607.0 L 657.0 621.0 L 664.0 639.0 L 668.0 664.0 L 668.0 674.0 L 666.0 675.0 L 651.0 647.0 L 641.0 632.0 L 623.0 612.0 L 609.0 601.0 L 595.0 592.0 L 566.0 578.0 L 470.0 544.0 L 472.0 533.0 L 475.0 530.0 L 542.0 542.0 L 569.0 543.0 L 586.0 541.0 L 602.0 537.0 L 629.0 524.0 L 649.0 506.0 L 659.0 491.0 L 664.0 478.0 L 665.0 456.0 L 659.0 442.0 L 651.0 432.0 L 643.0 426.0 L 631.0 420.0 L 621.0 417.0 L 453.0 389.0 L 422.0 389.0 L 411.0 391.0 L 396.0 396.0 Z"/>' +
            '<path d="M 727.0 194.0 L 710.0 198.0 L 693.0 207.0 L 680.0 220.0 L 670.0 240.0 L 668.0 252.0 L 670.0 422.0 L 677.0 431.0 L 682.0 441.0 L 686.0 457.0 L 686.0 476.0 L 701.0 488.0 L 715.0 494.0 L 724.0 496.0 L 747.0 496.0 L 764.0 491.0 L 781.0 480.0 L 794.0 464.0 L 800.0 449.0 L 801.0 396.0 L 802.0 395.0 L 803.0 252.0 L 800.0 236.0 L 792.0 221.0 L 782.0 210.0 L 770.0 202.0 L 758.0 197.0 L 743.0 194.0 Z"/>' +
            '<path d="M 559.0 165.0 L 548.0 170.0 L 533.0 182.0 L 525.0 193.0 L 518.0 211.0 L 517.0 243.0 L 518.0 244.0 L 519.0 378.0 L 625.0 396.0 L 643.0 402.0 L 651.0 407.0 L 652.0 406.0 L 653.0 281.0 L 654.0 280.0 L 654.0 215.0 L 651.0 202.0 L 642.0 186.0 L 631.0 175.0 L 616.0 166.0 L 596.0 161.0 L 575.0 161.0 Z"/>' +
            '<path d="M 876.0 262.0 L 857.0 265.0 L 841.0 272.0 L 826.0 285.0 L 818.0 299.0 L 816.0 306.0 L 817.0 454.0 L 820.0 464.0 L 825.0 474.0 L 837.0 487.0 L 853.0 496.0 L 863.0 499.0 L 888.0 500.0 L 905.0 496.0 L 922.0 486.0 L 935.0 471.0 L 941.0 456.0 L 942.0 450.0 L 942.0 307.0 L 936.0 291.0 L 931.0 284.0 L 921.0 275.0 L 911.0 269.0 L 900.0 265.0 Z"/>' +
            '<path d="M 477.0 232.0 L 456.0 222.0 L 439.0 219.0 L 425.0 219.0 L 409.0 222.0 L 393.0 229.0 L 382.0 237.0 L 374.0 246.0 L 366.0 261.0 L 363.0 277.0 L 364.0 363.0 L 365.0 364.0 L 365.0 388.0 L 366.0 389.0 L 384.0 378.0 L 401.0 372.0 L 421.0 368.0 L 444.0 367.0 L 464.0 369.0 L 496.0 375.0 L 500.0 374.0 L 501.0 270.0 L 499.0 261.0 L 495.0 252.0 L 488.0 242.0 Z"/>';
          case 'claw3': // triple horizontal claw slash (hand-traced streaks), tinted via emissive
            vb = '0 0 1254 1254';
            '<path d="M 1127.0 395.0 L 1064.0 400.0 L 1016.0 400.0 L 978.0 397.0 L 967.0 400.0 L 905.0 400.0 L 902.0 399.0 L 900.0 395.0 L 908.0 388.0 L 908.0 386.0 L 847.0 395.0 L 786.0 395.0 L 774.0 392.0 L 771.0 389.0 L 772.0 385.0 L 789.0 368.0 L 749.0 377.0 L 735.0 378.0 L 722.0 382.0 L 702.0 381.0 L 684.0 388.0 L 661.0 393.0 L 641.0 394.0 L 629.0 391.0 L 613.0 391.0 L 601.0 394.0 L 580.0 393.0 L 576.0 389.0 L 578.0 382.0 L 588.0 371.0 L 583.0 370.0 L 552.0 377.0 L 497.0 396.0 L 490.0 396.0 L 487.0 392.0 L 472.0 393.0 L 470.0 388.0 L 476.0 380.0 L 475.0 379.0 L 423.0 397.0 L 385.0 406.0 L 380.0 406.0 L 377.0 403.0 L 380.0 398.0 L 379.0 396.0 L 316.0 418.0 L 258.0 427.0 L 244.0 432.0 L 155.0 453.0 L 136.0 459.0 L 132.0 462.0 L 198.0 455.0 L 259.0 456.0 L 265.0 454.0 L 286.0 453.0 L 310.0 456.0 L 312.0 458.0 L 310.0 464.0 L 351.0 458.0 L 365.0 458.0 L 373.0 461.0 L 388.0 463.0 L 390.0 465.0 L 390.0 469.0 L 387.0 473.0 L 392.0 473.0 L 427.0 463.0 L 439.0 464.0 L 460.0 459.0 L 474.0 459.0 L 479.0 463.0 L 475.0 473.0 L 481.0 473.0 L 508.0 468.0 L 530.0 461.0 L 554.0 457.0 L 569.0 457.0 L 576.0 462.0 L 574.0 468.0 L 598.0 460.0 L 618.0 461.0 L 623.0 465.0 L 623.0 469.0 L 617.0 476.0 L 618.0 477.0 L 657.0 465.0 L 670.0 458.0 L 680.0 458.0 L 701.0 452.0 L 712.0 451.0 L 717.0 456.0 L 707.0 469.0 L 708.0 471.0 L 748.0 461.0 L 771.0 453.0 L 783.0 454.0 L 804.0 449.0 L 820.0 448.0 L 825.0 451.0 L 825.0 458.0 L 869.0 442.0 L 907.0 438.0 L 909.0 440.0 L 908.0 445.0 L 918.0 438.0 L 954.0 429.0 L 997.0 421.0 L 1007.0 421.0 L 1008.0 425.0 L 1112.0 401.0 Z"/>' +
            '<path d="M 121.0 651.0 L 207.0 644.0 L 247.0 644.0 L 251.0 646.0 L 294.0 644.0 L 310.0 649.0 L 312.0 651.0 L 311.0 654.0 L 356.0 648.0 L 372.0 652.0 L 384.0 652.0 L 386.0 657.0 L 389.0 657.0 L 399.0 653.0 L 417.0 650.0 L 434.0 652.0 L 451.0 648.0 L 466.0 648.0 L 470.0 654.0 L 461.0 665.0 L 463.0 666.0 L 505.0 657.0 L 521.0 651.0 L 534.0 651.0 L 552.0 647.0 L 563.0 647.0 L 570.0 651.0 L 568.0 658.0 L 596.0 649.0 L 605.0 649.0 L 608.0 653.0 L 625.0 653.0 L 628.0 656.0 L 628.0 659.0 L 619.0 669.0 L 621.0 670.0 L 666.0 657.0 L 682.0 649.0 L 693.0 649.0 L 720.0 642.0 L 730.0 642.0 L 733.0 645.0 L 732.0 650.0 L 724.0 661.0 L 785.0 643.0 L 797.0 644.0 L 824.0 638.0 L 835.0 638.0 L 838.0 641.0 L 838.0 645.0 L 835.0 650.0 L 837.0 651.0 L 864.0 639.0 L 885.0 632.0 L 918.0 628.0 L 920.0 630.0 L 918.0 634.0 L 920.0 635.0 L 933.0 627.0 L 974.0 617.0 L 1010.0 611.0 L 1018.0 611.0 L 1020.0 614.0 L 1024.0 614.0 L 1070.0 603.0 L 1109.0 596.0 L 1136.0 588.0 L 1096.0 590.0 L 1033.0 590.0 L 1023.0 588.0 L 990.0 587.0 L 987.0 584.0 L 989.0 579.0 L 980.0 580.0 L 967.0 585.0 L 915.0 583.0 L 911.0 580.0 L 911.0 577.0 L 922.0 566.0 L 860.0 581.0 L 834.0 580.0 L 817.0 583.0 L 797.0 583.0 L 790.0 579.0 L 791.0 573.0 L 805.0 560.0 L 798.0 560.0 L 765.0 567.0 L 753.0 567.0 L 731.0 574.0 L 700.0 573.0 L 671.0 580.0 L 664.0 580.0 L 648.0 575.0 L 633.0 575.0 L 606.0 582.0 L 590.0 583.0 L 585.0 582.0 L 580.0 578.0 L 582.0 570.0 L 591.0 560.0 L 591.0 558.0 L 587.0 558.0 L 569.0 563.0 L 555.0 564.0 L 526.0 578.0 L 518.0 579.0 L 502.0 585.0 L 478.0 589.0 L 473.0 588.0 L 471.0 583.0 L 479.0 568.0 L 424.0 587.0 L 388.0 595.0 L 378.0 595.0 L 376.0 591.0 L 379.0 587.0 L 376.0 586.0 L 323.0 605.0 L 300.0 610.0 L 285.0 610.0 L 263.0 614.0 L 233.0 623.0 L 133.0 646.0 Z"/>' +
            '<path d="M 1132.0 773.0 L 1084.0 777.0 L 1030.0 777.0 L 1007.0 775.0 L 1005.0 773.0 L 974.0 776.0 L 964.0 774.0 L 942.0 774.0 L 929.0 771.0 L 926.0 766.0 L 939.0 754.0 L 877.0 767.0 L 850.0 766.0 L 831.0 770.0 L 815.0 770.0 L 810.0 768.0 L 808.0 763.0 L 823.0 748.0 L 817.0 748.0 L 761.0 761.0 L 742.0 760.0 L 720.0 768.0 L 691.0 773.0 L 678.0 773.0 L 667.0 770.0 L 645.0 770.0 L 623.0 775.0 L 598.0 774.0 L 595.0 771.0 L 595.0 767.0 L 612.0 752.0 L 608.0 751.0 L 574.0 757.0 L 559.0 757.0 L 513.0 772.0 L 493.0 775.0 L 488.0 770.0 L 478.0 772.0 L 471.0 771.0 L 469.0 768.0 L 477.0 758.0 L 475.0 757.0 L 422.0 774.0 L 379.0 784.0 L 372.0 784.0 L 370.0 782.0 L 372.0 775.0 L 369.0 775.0 L 312.0 797.0 L 294.0 801.0 L 279.0 801.0 L 250.0 808.0 L 218.0 818.0 L 159.0 832.0 L 137.0 839.0 L 133.0 842.0 L 192.0 835.0 L 246.0 835.0 L 259.0 832.0 L 295.0 833.0 L 298.0 835.0 L 298.0 838.0 L 337.0 834.0 L 369.0 836.0 L 376.0 840.0 L 371.0 848.0 L 376.0 848.0 L 413.0 839.0 L 428.0 840.0 L 451.0 835.0 L 464.0 835.0 L 468.0 838.0 L 468.0 842.0 L 461.0 851.0 L 504.0 844.0 L 522.0 838.0 L 530.0 839.0 L 548.0 835.0 L 565.0 834.0 L 570.0 835.0 L 575.0 839.0 L 572.0 846.0 L 602.0 837.0 L 618.0 837.0 L 631.0 840.0 L 634.0 843.0 L 634.0 846.0 L 623.0 857.0 L 625.0 858.0 L 675.0 843.0 L 692.0 835.0 L 699.0 836.0 L 731.0 828.0 L 738.0 829.0 L 740.0 834.0 L 730.0 848.0 L 789.0 830.0 L 805.0 830.0 L 832.0 824.0 L 842.0 824.0 L 846.0 827.0 L 846.0 831.0 L 842.0 837.0 L 843.0 838.0 L 891.0 819.0 L 927.0 814.0 L 930.0 817.0 L 930.0 821.0 L 939.0 815.0 L 961.0 809.0 L 1010.0 799.0 L 1043.0 795.0 L 1102.0 782.0 Z"/>';
          case 'bolt': // lightning bolt
            '<path d="M58 10 L40 46 L55 50 L36 90 L72 42 L55 38 L66 10 Z" fill="#fff"/>';
          case 'curvedx': // curved-X hit mark (hand-traced), tinted via emissive
            vb = '0 0 1254 1254';
            '<path d="M 1074.0 203.0 L 1070.0 202.0 L 1044.0 212.0 L 989.0 239.0 L 941.0 267.0 L 877.0 310.0 L 828.0 347.0 L 771.0 394.0 L 714.0 445.0 L 652.0 504.0 L 644.0 499.0 L 598.0 455.0 L 539.0 404.0 L 484.0 361.0 L 427.0 321.0 L 370.0 286.0 L 306.0 253.0 L 250.0 229.0 L 210.0 215.0 L 205.0 216.0 L 240.0 244.0 L 298.0 294.0 L 362.0 354.0 L 457.0 450.0 L 577.0 579.0 L 438.0 723.0 L 341.0 833.0 L 297.0 888.0 L 252.0 949.0 L 221.0 995.0 L 192.0 1045.0 L 196.0 1045.0 L 263.0 988.0 L 391.0 886.0 L 478.0 813.0 L 557.0 740.0 L 644.0 651.0 L 646.0 651.0 L 796.0 799.0 L 1063.0 1046.0 L 1065.0 1046.0 L 1065.0 1037.0 L 1057.0 1012.0 L 1039.0 970.0 L 1003.0 905.0 L 974.0 862.0 L 939.0 816.0 L 881.0 747.0 L 802.0 660.0 L 718.0 572.0 L 939.0 331.0 L 1018.0 252.0 Z"/>';
          default: // swoosh: fat filled crescent — the motion trail behind an imaginary blade. faint
                   // wide body + a brighter narrow core so the trail edge falls off soft
            '<path d="M12 74 Q 50 -30 88 74 Q 50 40 12 74 Z" fill="#fff" opacity="0.45"/>' +
            '<path d="M22 72 Q 50 -6 78 72 Q 50 32 22 72 Z" fill="#fff"/>';
        };
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + vb + '" fill="#fff">' + body + '</svg>';
    }
}

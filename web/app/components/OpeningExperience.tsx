"use client";

import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";

const standardHoldMs = 4_850;
const reducedMotionHoldMs = 900;
const exitDurationMs = 650;

export function OpeningExperience() {
  const [visible, setVisible] = useState(true);
  const [leaving, setLeaving] = useState(false);
  const exitTimer = useRef<number | null>(null);

  const close = useCallback(() => {
    setLeaving(true);
    if (exitTimer.current !== null) window.clearTimeout(exitTimer.current);
    exitTimer.current = window.setTimeout(() => setVisible(false), exitDurationMs);
  }, []);

  useEffect(() => {
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const holdTimer = window.setTimeout(close, reducedMotion ? reducedMotionHoldMs : standardHoldMs);
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      window.clearTimeout(holdTimer);
      if (exitTimer.current !== null) window.clearTimeout(exitTimer.current);
      document.body.style.overflow = originalOverflow;
    };
  }, [close]);

  useEffect(() => {
    if (!visible) document.body.style.overflow = "";
  }, [visible]);

  if (!visible) return null;

  return (
    <div
      className="opening-experience"
      data-leaving={leaving}
      role="dialog"
      aria-label="MARKOUT opening sequence"
      aria-modal="true"
    >
      <div className="opening-grid" aria-hidden="true" />
      <div className="opening-scan" aria-hidden="true" />

      <div className="opening-topline" aria-hidden="true">
        <span>PYTH ETH/USD</span>
        <b>$2,438.51</b>
        <span className="opening-topline-live"><i /> SIGNED PRICE / LIVE</span>
      </div>

      <div className="opening-stage">
        <svg className="opening-flow-map" viewBox="0 0 1200 520" preserveAspectRatio="none" aria-hidden="true">
          <path className="opening-flow-base" pathLength="1" d="M40 260 C190 252 300 258 420 260" />
          <path className="opening-flow-adverse" pathLength="1" d="M420 260 C575 255 665 120 870 138 C1010 150 1060 82 1160 92" />
          <path className="opening-flow-good" pathLength="1" d="M420 260 C575 265 660 405 870 390 C1000 382 1075 447 1160 430" />
          <circle className="opening-execution-node" cx="420" cy="260" r="7" />
          <circle className="opening-adverse-node" cx="1160" cy="92" r="5" />
          <circle className="opening-good-node" cx="1160" cy="430" r="5" />
        </svg>

        <div className="opening-flow-label opening-flow-label-adverse" aria-hidden="true">
          <span>ADVERSE FLOW</span><strong>LP PROTECTION</strong>
        </div>
        <div className="opening-flow-label opening-flow-label-good" aria-hidden="true">
          <span>GOOD FLOW</span><strong>FEE RETURNED</strong>
        </div>

        <div className="opening-message opening-message-one" aria-hidden="true">
          <span>01 / EXECUTION</span>
          <strong>THE TRADE HAPPENS NOW.</strong>
        </div>
        <div className="opening-message opening-message-two" aria-hidden="true">
          <span>02 / EVIDENCE</span>
          <strong>THE OUTCOME ARRIVES LATER.</strong>
        </div>

        <div className="opening-brand-reveal">
          <span className="opening-brand-mark">M</span>
          <div className="opening-wordmark" aria-label="MARKOUT">
            {"MARKOUT".split("").map((letter, index) => (
              <span key={`${letter}-${index}`} style={{ "--letter-index": index } as CSSProperties}>
                {letter}
              </span>
            ))}
          </div>
          <div className="opening-rule" aria-hidden="true" />
          <p>OUTCOME-PRICED LIQUIDITY</p>
          <small>OBSERVE FIRST&nbsp;&nbsp;/&nbsp;&nbsp;ALLOCATE AFTER EVIDENCE</small>
        </div>
      </div>

      <div className="opening-footer" aria-hidden="true">
        <span>UNISWAP v4</span><i />
        <span>PYTH</span><i />
        <span>REACTIVE NETWORK</span>
      </div>

      <button className="opening-skip" type="button" onClick={close} aria-label="Skip opening animation">
        Skip intro <span>↗</span>
      </button>
    </div>
  );
}
